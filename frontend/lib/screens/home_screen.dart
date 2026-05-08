import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/article.dart';
import '../models/market_snapshot_item.dart';
import '../models/sports_scoreboard.dart';
import 'summary_screen.dart';
import '../services/api_service.dart';
import '../widgets/stock_watchlist_card.dart';
import '../widgets/sports_scoreboard_card.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _apiService = const ApiService();
  late final PageController _pageController;
  late final AnimationController _greetingAnimController;
  late final Animation<double> _greetingFade;
  late final Animation<Offset> _greetingSlide;

  List<Article> _articles = <Article>[];
  List<MarketSnapshotItem> _marketSnapshot = <MarketSnapshotItem>[];
  SportsScoreboard? _sportsScoreboard;
  final Set<String> _savedArticleKeys = <String>{};
  bool _isLoading = false;
  bool _isFirstLoad = true;
  bool _isMarketLoading = false;
  bool _isSportsLoading = false;
  List<String> _selectedTopics = <String>[];

  // Track current page for dot indicator
  int _currentPage = 0;
  String? _firstName;
  String _summaryTone = 'professional';

  /// Called externally (e.g. after Profile saves) to re-fetch with the new tone.
  Future<void> refresh() async {
    setState(() {
      _isFirstLoad = true;
      _articles = [];
    });
    await _fetchUserPreferences();
    await Future.wait([
      _fetchDailyDigest(),
      _fetchMarketSnapshot(),
      _fetchSportsScoreboard(),
    ]);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });

    // Greeting entrance animation
    _greetingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _greetingFade = CurvedAnimation(
      parent: _greetingAnimController,
      curve: Curves.easeOut,
    );
    _greetingSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _greetingAnimController,
      curve: Curves.easeOutCubic,
    ));
    _greetingAnimController.forward();

    _loadSavedArticleKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUserPreferences();
      _fetchDailyDigest();
      _fetchMarketSnapshot();
      _fetchSportsScoreboard();
    });
  }

  Future<void> _fetchUserPreferences() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client
          .from('user_preferences')
          .select('first_name, selected_topics, summary_tone')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted && row != null) {
        final List<dynamic> topicsJson = row['selected_topics'] as List<dynamic>? ?? [];
        setState(() {
          _firstName = row['first_name'] as String?;
          _summaryTone = row['summary_tone'] as String? ?? 'professional';
          _selectedTopics = topicsJson.map((e) => e.toString()).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _greetingAnimController.dispose();
    super.dispose();
  }

  // ── Data fetching (unchanged logic) ────────────────────────────────────────

  Future<void> _fetchDailyDigest() async {
    setState(() => _isLoading = true);
    try {
      // Ensure preferences are loaded if possible, or fallback
      if (_selectedTopics.isEmpty) {
        await _fetchUserPreferences();
      }
      
      final topics = _selectedTopics.isNotEmpty ? _selectedTopics : const ['World News'];
      debugPrint('PROV: Pulling topics from state: $topics');
      
      final articles = await _apiService.fetchDailyDigest(
        topics: topics,
        tone: _summaryTone,
      );
      if (!mounted) return;
      setState(() => _articles = articles);
    } catch (error) {
      if (!mounted) return;
      _showError('Failed to load digest: $error');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isFirstLoad = false;
      });
    }
  }

  Future<void> _fetchMarketSnapshot() async {
    setState(() => _isMarketLoading = true);
    try {
      final snap = await _apiService.fetchMarketSnapshot();
      if (!mounted) return;
      setState(() => _marketSnapshot = snap);
    } catch (_) {
      // First attempt failed (rate-limit / cold-start). Retry once after a delay.
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      try {
        final snap = await _apiService.fetchMarketSnapshot();
        if (!mounted) return;
        setState(() => _marketSnapshot = snap);
      } catch (_) {
        // Still failed — card renders empty silently.
        if (!mounted) return;
      }
    } finally {
      if (!mounted) return;
      setState(() => _isMarketLoading = false);
    }
  }

  Future<void> _fetchSportsScoreboard() async {
    setState(() => _isSportsLoading = true);
    try {
      final board = await _apiService.fetchSportsScoreboard();
      if (!mounted) return;
      setState(() => _sportsScoreboard = board);
    } catch (error) {
      if (!mounted) return;
      _showError('Failed to load sports scoreboard: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isSportsLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Article helpers (unchanged logic) ──────────────────────────────────────

  String _firstValidUrl(Article article) {
    for (final url in article.urls) {
      final t = url.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  String _articleKey(Article article) {
    final u = _firstValidUrl(article);
    return u.isNotEmpty ? 'url:$u' : 'title:${article.title.trim().toLowerCase()}';
  }

  List<String> _parseStringList(dynamic value) {
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? [] : [t];
    }
    if (value is List) {
      return value.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  String _parseFirstTitle(dynamic row) {
    if (row is! Map<String, dynamic>) return '';
    final title = (row['title'] as String? ?? '').trim();
    if (title.isNotEmpty) return title.toLowerCase();
    final titles = _parseStringList(row['titles']);
    return titles.isNotEmpty ? titles.first.toLowerCase() : '';
  }

  Future<void> _loadSavedArticleKeys() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
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
          if (!mounted) return;
      setState(() { _savedArticleKeys..clear()..addAll(keys); });
    } catch (_) {}
  }

  Future<void> _openSummary(Article article) async {
    final key     = _articleKey(article);
    final isSaved = _savedArticleKeys.contains(key);
    // Haptic pulse on tap
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, anim, __) => SummaryScreen(
          article: article,
          initiallySaved: isSaved,
          onSaved: () {
            if (!mounted) return;
            setState(() => _savedArticleKeys.add(key));
          },
        ),
        transitionsBuilder: (_, anim, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }

  // ── Greeting helpers ───────────────────────────────────────────────────────

  String _displayName() {
    if (_firstName != null && _firstName!.trim().isNotEmpty) {
      return _firstName!.trim();
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return '';
    final md = user.userMetadata;
    if (md is Map<String, dynamic>) {
      final fn = (md['full_name'] as String? ?? '').trim();
      if (fn.isNotEmpty) return fn;
      final n = (md['name'] as String? ?? '').trim();
      if (n.isNotEmpty) return n;
    }
    final email = (user.email ?? '').trim();
    return email.isEmpty ? '' : email.split('@').first;
  }

  String _greetingLabel() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  IconData _timeOfDayIcon() {
    final h = DateTime.now().hour;
    if (h < 12) return Icons.wb_sunny_outlined;
    if (h < 18) return Icons.wb_cloudy_outlined;
    return Icons.nightlight_round_outlined;
  }

  // ── UI Builders ────────────────────────────────────────────────────────────

  void _showFullStocks(BuildContext context) {
    if (_marketSnapshot.isEmpty) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: StockWatchlistCard(
          items: _marketSnapshot,
          isExpanded: true,
        ),
      ),
    );
  }

  void _showFullSports(BuildContext context) {
    if (_sportsScoreboard == null) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: SportsScoreboardCard(
          scoreboard: _sportsScoreboard,
          isLoading: _isSportsLoading,
          isExpanded: true,
        ),
      ),
    );
  }

  /// Full-screen immersive news card with image background + gradient overlay.
  Widget _buildArticleCard(Article article, int pageIndex) {
    debugPrint('Building card: ${article.title} | Image: ${article.imageUrl}');
    final imageUrl  = article.imageUrl?.trim() ?? '';
    final imageUri  = Uri.tryParse(imageUrl);
    final hasImage  = imageUrl.isNotEmpty &&
        imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty;
    final cs        = Theme.of(context).colorScheme;
    final tt        = Theme.of(context).textTheme;
    final topic     = article.sources.isNotEmpty ? article.sources.first : 'News';
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _openSummary(article),
      child: AnimatedScale(
        scale: _currentPage == pageIndex ? 1.0 : 0.94,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.5)
                    : AnonaColors.textPrimary.withOpacity(0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // ── Background image ──────────────────────────────────────
                if (hasImage)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackBg(cs),
                    loadingBuilder: (ctx, child, progress) =>
                        progress == null ? child : _buildFallbackBg(cs),
                  )
                else
                  _buildFallbackBg(cs),

                // ── Gradient overlay ──────────────────────────────────────
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.35, 0.75, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.55),
                        Colors.black.withOpacity(0.88),
                      ],
                    ),
                  ),
                ),

                // ── Content ───────────────────────────────────────────────
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Category pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          topic.toUpperCase(),
                          style: tt.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                offset: const Offset(0, 1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Headline
                      Text(
                        article.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: tt.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.6),
                              offset: const Offset(0, 2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Tap ripple ────────────────────────────────────────────
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openSummary(article),
                      borderRadius: BorderRadius.circular(28),
                      splashColor: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackBg(ColorScheme cs) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AnonaColors.primeNavy,
            AnonaColors.primeNavyMid,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 64,
          color: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }

  /// Dashboard card for Stocks (full-screen, green branding).
  Widget _buildMarketCardSection(int pageIndex) {
    if (_isMarketLoading && _marketSnapshot.isEmpty) {
      return _buildDashboardSkeleton(AnonaColors.moneyGreen);
    }
    return AnimatedScale(
      scale: _currentPage == pageIndex ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: StockWatchlistCard(
          items: _marketSnapshot,
          onTap: () => _showFullStocks(context),
        ),
      ),
    );
  }

  /// Dashboard card for Sports (full-screen, navy branding).
  Widget _buildSportsCardSection(int pageIndex) {
    if (_isSportsLoading && _sportsScoreboard == null) {
      return _buildDashboardSkeleton(AnonaColors.primeNavy);
    }
    return AnimatedScale(
      scale: _currentPage == pageIndex ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SportsScoreboardCard(
          scoreboard: _sportsScoreboard,
          isLoading: _isSportsLoading,
          onTap: () => _showFullSports(context),
        ),
      ),
    );
  }

  Widget _buildDashboardSkeleton(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDeck({required bool showStocks, required bool showSports}) {
    final count = _articles.length +
        (showStocks ? 1 : 0) +
        (showSports ? 1 : 0);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.62,
      child: PageView.builder(
        controller: _pageController,
        itemCount: count,
        itemBuilder: (BuildContext context, int index) {
          if (index < _articles.length) {
            return _buildArticleCard(_articles[index], index);
          }
          if (showStocks && index == _articles.length) {
            return _buildMarketCardSection(index);
          }
          if (showSports && index == _articles.length + (showStocks ? 1 : 0)) {
            return _buildSportsCardSection(index);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPageDots(int totalCount) {
    if (totalCount <= 1) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalCount, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? cs.primary
                : cs.onSurface.withOpacity(0.18),
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }),
    );
  }

  Widget _buildLoadingState() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Branded pulsing logo area
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 28),
          Text(
            'Getting your personalized\nnews ready…',
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Curating stories based on your interests',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 140,
            child: LinearProgressIndicator(
              borderRadius: BorderRadius.circular(100),
              minHeight: 3,
              color: cs.primary,
              backgroundColor: cs.primary.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.newspaper_outlined, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No content available right now.', style: tt.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName();
    final greeting = displayName.isEmpty
        ? _greetingLabel()
        : '${_greetingLabel()}, ${displayName.split(' ').first}';
    const showStocks = true;
    const showSports = true;
    final hasAny     = _articles.isNotEmpty || showStocks || showSports;
    final totalCount = _articles.length +
        (showStocks ? 1 : 0) +
        (showSports ? 1 : 0);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _fetchUserPreferences(),
          _fetchDailyDigest(),
          _fetchMarketSnapshot(),
          _fetchSportsScoreboard(),
        ]);
      },
      color: cs.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          // ── Greeting header ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: FadeTransition(
                opacity: _greetingFade,
                child: SlideTransition(
                  position: _greetingSlide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: [
                          Icon(_timeOfDayIcon(), size: 22, color: cs.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            'Anona',
                            style: tt.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        greeting,
                        style: tt.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your one-and-done morning briefing',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Deck / loading / empty ─────────────────────────────────────
          if (_isFirstLoad && _isLoading)
            _buildLoadingState()
          else if (!hasAny)
            _buildEmptyState()
          else ...[
            SliverToBoxAdapter(
              child: _buildDeck(showStocks: showStocks, showSports: showSports),
            ),

            // ── Page indicator dots ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _buildPageDots(totalCount),
              ),
            ),
          ],

          // Bottom breathing room
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
