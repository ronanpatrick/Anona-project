import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/article.dart';
import '../services/api_service.dart';
import '../widgets/audio_briefing_player.dart';
import '../theme/app_theme.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({
    required this.article,
    required this.initiallySaved,
    super.key,
    this.onSaved,
  });

  final Article article;
  final bool initiallySaved;
  final VoidCallback? onSaved;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = const ApiService();
  bool _isDeepDiveLoading = false;
  bool _isSaved = false;

  late final AnimationController _headerAnimCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.initiallySaved;

    _headerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _headerAnimCtrl,
      curve: Curves.easeOut,
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimCtrl,
      curve: Curves.easeOutCubic,
    ));
    _headerAnimCtrl.forward();
  }

  @override
  void dispose() {
    _headerAnimCtrl.dispose();
    super.dispose();
  }

  // ── Helpers (unchanged logic) ───────────────────────────────────────────────

  String _firstValidUrl(Article article) {
    for (final url in article.urls) {
      final t = url.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  String _articleKey(Article article) {
    final u = _firstValidUrl(article);
    return u.isNotEmpty
        ? 'url:$u'
        : 'title:${article.title.trim().toLowerCase()}';
  }

  String _displaySource() {
    final s = widget.article.sources
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return s.isEmpty ? 'Unknown source' : s.join(', ');
  }

  String _displayDate() {
    final raw = widget.article.publishedAt?.trim() ?? '';
    return raw.isEmpty ? 'Unknown date' : raw;
  }

  String _narrationText() =>
      '${widget.article.title}. Source: ${_displaySource()}. '
      'Date: ${_displayDate()}. ${widget.article.summary}';

  List<String> _validUrls() {
    return widget.article.urls.map((u) => u.trim()).where((u) => u.isNotEmpty).toList();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) { _showSnack('Invalid source URL'); return; }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _showSnack('Could not open source URL');
  }

  Future<void> _openOriginalSource() async {
    final validUrls = _validUrls();
    if (validUrls.isEmpty) {
      _showSnack('No source URL available');
      return;
    }
    if (validUrls.length == 1) {
      await _launchUrl(validUrls.first);
      return;
    }
    await _showSourcePickerSheet(validUrls);
  }

  Future<void> _showSourcePickerSheet(List<String> urls) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sources = widget.article.sources.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            color: isDark
                ? AnonaColors.surfaceDark.withOpacity(0.94)
                : Colors.white.withOpacity(0.96),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Center(
                    child: Text('Select Source', style: tt.titleLarge),
                  ),
                ),
                const Divider(height: 1),
                ...List.generate(urls.length, (index) {
                  final url = urls[index];
                  final sourceName = (sources.length > index) ? sources[index] : 'Source ${index + 1}';
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.public, size: 18, color: cs.primary),
                        ),
                        title: Text(sourceName, style: tt.titleMedium),
                        subtitle: Text(
                          url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _launchUrl(url);
                        },
                      ),
                      if (index < urls.length - 1)
                        const Divider(height: 1, indent: 72),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _originalButtonText() {
    final validUrls = _validUrls();
    if (validUrls.length > 1) {
      return 'Sources (${validUrls.length})';
    }
    return 'Original';
  }

  Future<void> _showDeepDive() async {
    final url = _firstValidUrl(widget.article);
    if (url.isEmpty) { _showSnack('No article URL available'); return; }

    setState(() => _isDeepDiveLoading = true);
    try {
      final analysis = await _apiService.fetchDeepDive(
        url,
        fallbackText: widget.article.summary,
      );
      if (!mounted) return;
      await _showDeepDiveSheet(analysis);
    } catch (error) {
      if (!mounted) return;
      _showSnack('Failed to load deep dive: $error');
    } finally {
      if (mounted) setState(() => _isDeepDiveLoading = false);
    }
  }

  Future<void> _showDeepDiveSheet(String analysis) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              color: isDark
                  ? AnonaColors.surfaceDark.withOpacity(0.94)
                  : Colors.white.withOpacity(0.96),
              child: Column(
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.auto_awesome,
                              size: 18, color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Deep Dive',
                              style: tt.titleLarge),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: cs.surfaceContainerHighest,
                            shape: const CircleBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      child: _buildDeepDiveContent(analysis, cs, tt),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Renders the deep dive plain-text output with styled section headers,
  /// clean bullet rows, and readable body paragraphs — no raw markdown visible.
  Widget _buildDeepDiveContent(String text, ColorScheme cs, TextTheme tt) {
    // Section header labels (ALL CAPS) produced by the updated prompt
    const sectionLabels = {
      'EXECUTIVE SUMMARY',
      'KEY STATISTICS',
      'DIRECT QUOTES',
      'TERMS EXPLAINED',
      'WHY IT MATTERS',
      'WHAT TO WATCH',
    };

    // Regex to detect and strip any leading bullet-like characters
    final bulletPrefixRe = RegExp(r'^[\-\*•·]+\s*');
    bool isBulletLine(String s) => s.startsWith('- ') || s.startsWith('* ') ||
        s.startsWith('• ') || s.startsWith('· ') ||
        RegExp(r'^[•·]').hasMatch(s);

    // ── First pass: group continuation lines into their bullet ─────────────
    // Each entry is either a section label, a bullet string, or a plain paragraph.
    final List<({String type, String content})> entries = [];
    String? pendingBullet;

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        if (pendingBullet != null) {
          entries.add((type: 'bullet', content: pendingBullet));
          pendingBullet = null;
        }
        continue;
      }

      if (sectionLabels.contains(line)) {
        if (pendingBullet != null) {
          entries.add((type: 'bullet', content: pendingBullet));
          pendingBullet = null;
        }
        entries.add((type: 'header', content: line));
        continue;
      }

      if (isBulletLine(line)) {
        if (pendingBullet != null) {
          entries.add((type: 'bullet', content: pendingBullet));
        }
        // Strip all leading bullet chars + spaces
        pendingBullet = line.replaceFirst(bulletPrefixRe, '').trim();
        continue;
      }

      // Continuation or plain paragraph
      if (pendingBullet != null) {
        pendingBullet = '$pendingBullet $line';
      } else {
        entries.add((type: 'para', content: line));
      }
    }
    if (pendingBullet != null) {
      entries.add((type: 'bullet', content: pendingBullet));
    }

    // ── Second pass: build widgets ─────────────────────────────────────────
    final widgets = <Widget>[];
    bool firstSection = true;

    for (final entry in entries) {
      switch (entry.type) {
        case 'header':
          if (!firstSection) widgets.add(const SizedBox(height: 20));
          firstSection = false;
          widgets.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.content,
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          );
          widgets.add(const SizedBox(height: 10));

        case 'bullet':
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(entry.content,
                        style: tt.bodyMedium?.copyWith(height: 1.5)),
                  ),
                ],
              ),
            ),
          );

        default: // 'para'
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                entry.content,
                style: tt.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<String> _parseStringList(dynamic value) {
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? [] : [t];
    }
    if (value is List) {
      return value
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  String _parseFirstTitle(dynamic row) {
    if (row is! Map<String, dynamic>) return '';
    final t = (row['title'] as String? ?? '').trim();
    if (t.isNotEmpty) return t.toLowerCase();
    final ts = _parseStringList(row['titles']);
    return ts.isNotEmpty ? ts.first.toLowerCase() : '';
  }

  Future<String> _getOrCreateDefaultFolderId(String userId) async {
    final client = Supabase.instance.client;
    final existing = await client
        .from('folders')
        .select('id')
        .eq('user_id', userId)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      final id = (existing['id'] as String? ?? '').trim();
      if (id.isNotEmpty) return id;
    }
    final created = await client
        .from('folders')
        .insert(<String, dynamic>{'user_id': userId, 'name': 'Saved'})
        .select('id')
        .single();
    final id = (created['id'] as String? ?? '').trim();
    if (id.isEmpty) throw const FormatException('Failed to create a default folder.');
    return id;
  }

  Future<void> _saveArticle() async {
    if (_isSaved) { _showSnack('Already saved.'); return; }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) { _showSnack('Please sign in to save articles.'); return; }

    final key = _articleKey(widget.article);
    try {
      final rows = await Supabase.instance.client
          .from('saved_summaries')
          .select('title,titles,urls')
          .eq('user_id', user.id);

      final keys = <String>{};
      for (final item in rows.whereType<Map<String, dynamic>>()) {
        final urls = _parseStringList(item['urls']);
        if (urls.isNotEmpty) { keys.add('url:${urls.first}'); continue; }
        final t = _parseFirstTitle(item);
        if (t.isNotEmpty) keys.add('title:$t');
      }
    
      if (keys.contains(key)) {
        if (!mounted) return;
        setState(() => _isSaved = true);
        _showSnack('Already saved.');
        return;
      }

      final folderId = await _getOrCreateDefaultFolderId(user.id);
      final payload = <String, dynamic>{
        'user_id':   user.id,
        'folder_id': folderId,
        'summary':   widget.article.summary,
        'titles':    <String>[widget.article.title],
        'sources':   widget.article.sources,
        'urls':      widget.article.urls,
        'image_url': widget.article.imageUrl,
      }..removeWhere((_, v) => v == null);

      await Supabase.instance.client.from('saved_summaries').insert(payload);
      if (!mounted) return;
      setState(() => _isSaved = true);
      widget.onSaved?.call();
      HapticFeedback.lightImpact();
      _showSnack('Saved to bookmarks ✓');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showSnack('Save failed: ${error.message}');
    } on FormatException catch (error) {
      if (!mounted) return;
      _showSnack('Save failed: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Save failed: $error');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  Widget _buildHeroImage() {
    final imageUrl = widget.article.imageUrl?.trim() ?? '';
    final imageUri = Uri.tryParse(imageUrl);
    final hasImage = imageUrl.isNotEmpty &&
        imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty;
    final cs = Theme.of(context).colorScheme;

    if (!hasImage) {
      return Container(
        height: 220,
        width: double.infinity,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.article_outlined, size: 56,
            color: cs.onSurfaceVariant.withOpacity(0.3)),
      );
    }

    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: cs.surfaceContainerHighest,
              child: Icon(Icons.broken_image_outlined, size: 48,
                  color: cs.onSurfaceVariant),
            ),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : Container(color: cs.surfaceContainerHighest),
          ),
          // Subtle bottom fade to match scaffold bg
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBody() {
    final summary = widget.article.summary.trim();
    final tt      = Theme.of(context).textTheme;
    final cs      = Theme.of(context).colorScheme;

    // Only '• ' (Unicode bullet, U+2022) signals intentional executive-tone bullets.
    // The AI prompt for executive tone explicitly uses '• '. All other prefixes
    // ('- ', '* ', etc.) are treated as prose to avoid misdetection.
    final rawLines = summary.split('\n');
    final hasBullets = rawLines.any((l) => l.trim().startsWith('• '));

    if (!hasBullets) {
      // ── Prose: join any single-newline-wrapped lines into paragraphs ─────
      final paragraphs = summary
          .split(RegExp(r'\n{2,}'))
          .map((p) => p.replaceAll('\n', ' ').trim())
          .where((p) => p.isNotEmpty)
          .toList();

      if (paragraphs.length <= 1) {
        // Single block — just render as-is, replacing lone newlines with spaces
        final clean = summary.replaceAll('\n', ' ').trim();
        return Text(clean, style: tt.bodyLarge?.copyWith(height: 1.65));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paragraphs.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(p, style: tt.bodyLarge?.copyWith(height: 1.65)),
        )).toList(),
      );
    }

    // ── Executive bullet list ─────────────────────────────────────────────
    // Group continuation lines (lines without '• ' prefix) into their bullet.
    final List<String> bulletItems = [];
    String? pending;

    for (final raw in rawLines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('• ')) {
        if (pending != null) bulletItems.add(pending);
        pending = line.substring(2).trim(); // strip '• '
      } else if (pending != null) {
        pending = '$pending $line'; // join continuation
      } else {
        bulletItems.add(line); // pre-bullet text
      }
    }
    if (pending != null) bulletItems.add(pending);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bulletItems.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item, style: tt.bodyLarge?.copyWith(height: 1.55)),
            ),
          ],
        ),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final cs      = Theme.of(context).colorScheme;
    final tt      = Theme.of(context).textTheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: <Widget>[
        Scaffold(
          backgroundColor: cs.surface,
          // Transparent app bar that merges into the hero image
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: _buildBlurButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).pop(),
              cs: cs,
            ),
            actions: [
              _buildBlurButton(
                icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                onTap: _saveArticle,
                cs: cs,
                tint: _isSaved ? cs.primary : null,
              ),
              const SizedBox(width: 8),
            ],
          ),

          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Hero image (edge to edge)
                _buildHeroImage(),

                // Content padding
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: SlideTransition(
                      position: _headerSlide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Source pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _displaySource().toUpperCase(),
                              style: tt.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Article title
                          Text(
                            article.title,
                            style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Meta row
                          _buildMetaRow(Icons.calendar_today_outlined, _displayDate()),
                          const SizedBox(height: 24),

                          // Divider
                          Divider(color: cs.outline.withOpacity(0.5)),
                          const SizedBox(height: 24),

                          // Summary body
                          _buildSummaryBody(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom action bar ────────────────────────────────────────────
          bottomNavigationBar: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AnonaColors.surfaceDark.withOpacity(0.88)
                      : cs.surface.withOpacity(0.9),
                  border: Border(
                    top: BorderSide(
                      color: cs.outline.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Frosted-glass audio player pill
                        AudioBriefingPlayer(
                          narrationText: _narrationText(),
                          title: 'Audio Briefing',
                          subtitle: 'Listen to this summary',
                        ),
                        const SizedBox(height: 10),
                        // Action buttons
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openOriginalSource,
                                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                label: Text(_originalButtonText()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isDeepDiveLoading ? null : _showDeepDive,
                                icon: _isDeepDiveLoading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                                label: const Text('Deep Dive'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlurButton({
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme cs,
    Color? tint,
  }) {
    final isDark = cs.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18,
                  color: tint ?? (isDark ? Colors.white : Colors.black)),
            ),
          ),
        ),
      ),
    );
  }
}
