import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/article.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_briefing_player.dart';

class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  final ApiService _apiService = const ApiService();

  final Set<String> _savedArticleKeys = <String>{};
  List<Article> _digestArticles = <Article>[];
  List<Article> _discoveryArticles = <Article>[];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedArticleKeys();
    _loadBriefingData();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<({List<String> topics, String tone})> _loadUserPreferences() async {
    const defaultTopics = <String>['World News'];
    const defaultTone = 'professional';

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return (topics: defaultTopics, tone: defaultTone);

    try {
      final row = await Supabase.instance.client
          .from('user_preferences')
          .select('selected_topics, summary_tone')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) return (topics: defaultTopics, tone: defaultTone);

      final topicValues = row['selected_topics'];
      final rawTone = row['summary_tone'] as String?;

      final topics = (topicValues is List)
          ? topicValues
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
          : defaultTopics;

      const allowedTones = ['executive', 'professional', 'conversationalist', 'layman'];
      final tone = (rawTone != null && allowedTones.contains(rawTone.toLowerCase()))
          ? rawTone.toLowerCase()
          : defaultTone;

      return (topics: topics.isEmpty ? defaultTopics : topics, tone: tone);
    } catch (_) {
      return (topics: defaultTopics, tone: defaultTone);
    }
  }

  Future<void> _loadBriefingData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await _loadUserPreferences();
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _apiService.fetchDailyDigest(topics: prefs.topics, tone: prefs.tone),
        _apiService.fetchDiscoveryNews(excludedTopics: prefs.topics, tone: prefs.tone),
      ]);
      if (!mounted) return;
      setState(() {
        _digestArticles    = results[0] as List<Article>;
        _discoveryArticles = results[1] as List<Article>;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load briefing: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _ttsText() => _digestArticles
      .map((a) => '${a.title}. ${a.summary.replaceAll(RegExp(r'[-*•]\s*'), ' ').replaceAll('\n', ' ')}')
      .join(' ');

  String _firstValidUrl(Article a) =>
      a.urls.map((u) => u.trim()).firstWhere((u) => u.isNotEmpty, orElse: () => '');

  String _articleKey(Article a) {
    final u = _firstValidUrl(a);
    return u.isNotEmpty ? 'url:$u' : 'title:${a.title.trim().toLowerCase()}';
  }

  List<String> _parseStringList(dynamic v) {
    if (v is String) return v.trim().isEmpty ? [] : [v.trim()];
    if (v is List) return v.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return [];
  }

  Future<void> _loadSavedArticleKeys() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('saved_summaries')
          .select('titles,urls')
          .eq('user_id', user.id);
      final keys = <String>{};
      for (final item in rows.whereType<Map<String, dynamic>>()) {
        final urls = _parseStringList(item['urls']);
        if (urls.isNotEmpty) { keys.add('url:${urls.first}'); continue; }
        final titles = _parseStringList(item['titles']);
        if (titles.isNotEmpty) keys.add('title:${titles.first.toLowerCase()}');
      }
      if (!mounted) return;
      setState(() { _savedArticleKeys..clear()..addAll(keys); });
    } catch (_) {}
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open source URL')),
      );
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AnonaColors.backgroundDark : AnonaColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: _loadBriefingData,
        color: cs.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero player header ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeroPlayer(cs, tt, isDark),
            ),

            // ── Loading / content ──────────────────────────────────────────
            if (_isLoading && _digestArticles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 28, height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                      ),
                      const SizedBox(height: 12),
                      Text('Loading your briefing…',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              )
            else ...[
              // Today's digest headlines
              if (_digestArticles.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _SectionHeader(label: "Today's Stories", icon: Icons.article_outlined),
                      const SizedBox(height: 4),
                      ..._digestArticles.asMap().entries.map((e) =>
                          _DigestRow(index: e.key + 1, article: e.value)),
                    ]),
                  ),
                ),

              // Discovery section
              if (_discoveryArticles.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _SectionHeader(label: 'Discover', icon: Icons.explore_outlined),
                      const SizedBox(height: 4),
                      ..._discoveryArticles.map((a) => _DiscoveryRow(
                        article: a,
                        isSaved: _savedArticleKeys.contains(_articleKey(a)),
                        onTap: () => _showDiscoverySheet(a),
                      )),
                    ]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPlayer(ColorScheme cs, TextTheme tt, bool isDark) {
    final narration = _ttsText();
    final articleCount = _digestArticles.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [cs.primary.withOpacity(0.18), cs.primary.withOpacity(0.06)]
                    : [cs.primary.withOpacity(0.1), cs.primary.withOpacity(0.03)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: cs.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.mic_rounded, size: 18, color: cs.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Audio Briefing',
                                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            Text(
                              _isLoading
                                  ? 'Loading…'
                                  : articleCount > 0
                                      ? '$articleCount stories · ~${(articleCount * 45 / 60).ceil()} min'
                                      : 'No stories yet',
                              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      // Refresh button
                      IconButton(
                        onPressed: _isLoading ? null : _loadBriefingData,
                        icon: Icon(Icons.refresh_rounded, size: 18, color: cs.onSurfaceVariant),
                        style: IconButton.styleFrom(
                          backgroundColor: cs.onSurface.withOpacity(0.06),
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: cs.outline.withOpacity(0.2), height: 1),
                ),
                const SizedBox(height: 16),

                // Audio player
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: AudioBriefingPlayer(
                    narrationText: narration,
                    title: 'Your Daily Brief',
                    subtitle: articleCount > 0
                        ? 'Tap play to listen to $articleCount stories'
                        : 'Loading stories…',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDiscoverySheet(Article article) async {
    final isSaved = _savedArticleKeys.contains(_articleKey(article));
    final sourceUrl = _firstValidUrl(article);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: isDark ? AnonaColors.surfaceDark.withOpacity(0.96) : Colors.white.withOpacity(0.97),
              child: Column(
                children: [
                  // Handle
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (article.sources.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                article.sources.first.toUpperCase(),
                                style: tt.labelSmall?.copyWith(
                                  color: cs.primary, fontWeight: FontWeight.w700, letterSpacing: 1),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(article.title,
                              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                          const SizedBox(height: 12),
                          Text(article.summary, style: tt.bodyMedium?.copyWith(height: 1.6)),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: isSaved ? null : () {
                                  Navigator.pop(context);
                                },
                                icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 16),
                                label: Text(isSaved ? 'Saved' : 'Save'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: cs.outline.withOpacity(0.4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: sourceUrl.isEmpty ? null : () => _openExternalUrl(sourceUrl),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                  label: const Text('Read Original'),
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text(label,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                letterSpacing: 0.2,
              )),
        ],
      ),
    );
  }
}

class _DigestRow extends StatelessWidget {
  const _DigestRow({required this.index, required this.article});
  final int index;
  final Article article;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.title,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.4)),
                if (article.sources.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(article.sources.first,
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryRow extends StatelessWidget {
  const _DiscoveryRow({
    required this.article,
    required this.isSaved,
    required this.onTap,
  });
  final Article article;
  final bool isSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: cs.primary,
                      )),
                  if (article.sources.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(article.sources.first,
                        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_outward_rounded, size: 15, color: cs.primary.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
