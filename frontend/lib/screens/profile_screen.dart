import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/onboarding_state.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _glassCard({required Widget child, EdgeInsets? padding, double radius = 20}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
          padding: padding ?? const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, {String? subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white : AnonaColors.textPrimary,
                  fontWeight: FontWeight.w700,
                )),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark ? AnonaColors.silverText : AnonaColors.textSecondary,
                  )),
        ],
      ],
    );
  }

  InputDecoration _glassInput(String label, {Widget? suffixIcon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark ? AnonaColors.silverText : AnonaColors.textSecondary;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: hintColor, fontSize: 13),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AnonaColors.moneyGreenLight, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stockSearchController = TextEditingController();

  // State
  List<String> _selectedTopics = [];
  List<String> _selectedSportsTeams = [];
  List<String> _selectedStocks = [];
  SummaryTone _summaryTone = SummaryTone.analyst;
  String _activeLeague = sportsLeagues.first;
  TimeOfDay _briefingTime = const TimeOfDay(hour: 8, minute: 0);
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockSearchController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        Supabase.instance.client
            .from('profiles')
            .select('name,full_name')
            .eq('id', user.id)
            .maybeSingle(),
        Supabase.instance.client
            .from('user_preferences')
            .select('first_name,selected_topics,summary_tone,sports_teams,stock_tickers,briefing_time')
            .eq('id', user.id)
            .maybeSingle(),
      ]);
      final profileRow = results[0] as Map<String, dynamic>?;
      final prefRow = results[1] as Map<String, dynamic>?;

      _nameController.text =
          ((prefRow?['first_name'] as String?) ?? (profileRow?['name'] as String?) ?? (profileRow?['full_name'] as String?) ?? '').trim();
      _selectedTopics = _parseList(prefRow?['selected_topics']);
      _selectedSportsTeams = _parseList(prefRow?['sports_teams']);
      _selectedStocks = _parseList(prefRow?['stock_tickers']);
      _summaryTone = SummaryTone.fromDbValue(prefRow?['summary_tone'] as String?);
      
      final bt = prefRow?['briefing_time'] as String?;
      if (bt != null && bt.contains(':')) {
        final parts = bt.split(':');
        _briefingTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to load profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      await Future.wait<dynamic>([
        Supabase.instance.client.from('profiles').upsert(
          {
            'id': user.id,
            'name': _nameController.text.trim(),
            'full_name': _nameController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'id',
        ),
        Supabase.instance.client.from('user_preferences').upsert(
          {
            'id': user.id,
            'first_name': _nameController.text.trim(),
            'selected_topics': _selectedTopics,
            'summary_tone': _summaryTone.dbValue,
            'sports_teams': _selectedSportsTeams,
            'stock_tickers': _selectedStocks,
            'briefing_time': '${_briefingTime.hour.toString().padLeft(2, '0')}:${_briefingTime.minute.toString().padLeft(2, '0')}',
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'id',
        ),
      ]);
      
      await NotificationService().scheduleDailyBriefing(_briefingTime);
      if (!mounted) return;
      _showSnack('Changes saved ✓');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Unable to save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<String> _parseList(dynamic v) {
    if (v is! List) return [];
    return v.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  void _toggleTopic(String t) => setState(() {
        _selectedTopics.contains(t) ? _selectedTopics.remove(t) : _selectedTopics.add(t);
      });

  void _toggleTeam(String t) => setState(() {
        _selectedSportsTeams.contains(t) ? _selectedSportsTeams.remove(t) : _selectedSportsTeams.add(t);
      });

  void _toggleStock(String s) => setState(() {
        _selectedStocks.contains(s) ? _selectedStocks.remove(s) : _selectedStocks.add(s);
      });

  void _addCustomStock() {
    final v = _stockSearchController.text.trim().toUpperCase();
    if (v.isEmpty) return;
    if (!_selectedStocks.contains(v)) setState(() => _selectedStocks.add(v));
    _stockSearchController.clear();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AnonaColors.lossRed : AnonaColors.moneyGreen,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: isDark ? AnonaColors.backgroundDark : AnonaColors.backgroundLight,
      extendBody: true,
      bottomNavigationBar: _buildStickyBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AnonaColors.moneyGreenLight))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF0A0F1E), const Color(0xFF000000)]
                      : [const Color(0xFFFDFDFB), const Color(0xFFF5F5F0)],
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildIdentityCard(email),
                        const SizedBox(height: 16),
                        _buildTimeCard(),
                        const SizedBox(height: 16),
                        _buildTopicsCard(),
                        const SizedBox(height: 16),
                        _buildToneCard(),
                        const SizedBox(height: 16),
                        _buildSportsCard(),
                        const SizedBox(height: 16),
                        _buildStocksCard(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 60,
      floating: true,
      pinned: false,
      title: Text('My Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isDark ? Colors.white : AnonaColors.textPrimary,
                fontWeight: FontWeight.w800,
              )),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton(
            onPressed: () => _loadProfileData(),
            child: const Text('Refresh',
                style: TextStyle(color: AnonaColors.moneyGreenLight, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  // ── Identity Card ─────────────────────────────────────────────────────────

  Widget _buildIdentityCard(String email) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _glassCard(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: isDark ? AnonaColors.surfaceDark2 : Colors.black12,
                child: Icon(Icons.person, size: 48, color: isDark ? AnonaColors.silverText : Colors.black38),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: AnonaColors.moneyGreenLight,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(5),
                child: const Icon(Icons.edit, size: 13, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (email.isNotEmpty)
            Text(email,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isDark ? AnonaColors.silverText : AnonaColors.textSecondary,
                    )),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            style: TextStyle(color: isDark ? Colors.white : AnonaColors.textPrimary),
            decoration: _glassInput('Name',
                suffixIcon: Icon(Icons.badge_outlined, color: isDark ? AnonaColors.silverText : AnonaColors.textSecondary, size: 18)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _staticField('Date of Birth', Icons.cake_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _staticField('Sex', Icons.wc_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _staticField(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isDark ? AnonaColors.silverText : AnonaColors.textSecondary),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(color: isDark ? AnonaColors.silverText : AnonaColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Time Card ─────────────────────────────────────────────────────────────

  Widget _buildTimeCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeString = _briefingTime.format(context);

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Daily Briefing', subtitle: 'When should we notify you?'),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              final newTime = await showTimePicker(
                context: context,
                initialTime: _briefingTime,
              );
              if (newTime != null) {
                setState(() => _briefingTime = newTime);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_outlined, size: 20, color: isDark ? AnonaColors.silverText : AnonaColors.textSecondary),
                      const SizedBox(width: 12),
                      Text('Delivery Time',
                          style: TextStyle(color: isDark ? Colors.white : AnonaColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Row(
                    children: [
                      Text(timeString,
                          style: const TextStyle(color: AnonaColors.moneyGreenLight, fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Icon(Icons.edit_outlined, size: 16, color: isDark ? AnonaColors.silverText : AnonaColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Topics Card ───────────────────────────────────────────────────────────

  Widget _buildTopicsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Topics', subtitle: 'Pick what you want to follow'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: onboardingTopics.map((topic) {
              final selected = _selectedTopics.contains(topic);
              return FilterChip(
                label: Text(topic),
                selected: selected,
                onSelected: (_) => _toggleTopic(topic),
                selectedColor: AnonaColors.moneyGreen.withOpacity(0.25),
                checkmarkColor: AnonaColors.moneyGreenLight,
                backgroundColor: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04),
                labelStyle: TextStyle(
                  color: selected
                      ? AnonaColors.moneyGreenLight
                      : (isDark ? AnonaColors.silverText : AnonaColors.textSecondary),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: BorderSide(
                    color: selected ? AnonaColors.moneyGreen : (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Tone Card ─────────────────────────────────────────────────────────────

  Widget _buildToneCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Summary Tone', subtitle: 'How should Anona talk to you?'),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: SummaryTone.values.map((tone) {
              final selected = _summaryTone == tone;
              return GestureDetector(
                onTap: () => setState(() => _summaryTone = tone),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected
                        ? AnonaColors.moneyGreen.withOpacity(0.2)
                        : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AnonaColors.moneyGreenLight
                          : (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(tone.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(tone.label,
                                style: TextStyle(
                                  color: selected
                                      ? AnonaColors.moneyGreenLight
                                      : (isDark ? Colors.white : AnonaColors.textPrimary),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(tone.subtitle,
                          style: TextStyle(
                              color: isDark ? AnonaColors.silverText : AnonaColors.textSecondary,
                              fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Sports Card ───────────────────────────────────────────────────────────

  Widget _buildSportsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teams = leagueTeams[_activeLeague] ?? [];
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Sports Teams', subtitle: 'Track your favourite teams'),
          const SizedBox(height: 14),
          // League filter row
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sportsLeagues.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final league = sportsLeagues[i];
                final active = _activeLeague == league;
                return GestureDetector(
                  onTap: () => setState(() => _activeLeague = league),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? AnonaColors.primeNavyAccent : (isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04)),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: active ? AnonaColors.primeNavyAccent : (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1)),
                      ),
                    ),
                    child: Text(league,
                        style: TextStyle(
                          color: active ? Colors.white : (isDark ? AnonaColors.silverText : AnonaColors.textSecondary),
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // Team grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: teams.map((team) {
              final sel = _selectedSportsTeams.contains(team);
              return FilterChip(
                label: Text(team),
                selected: sel,
                onSelected: (_) => _toggleTeam(team),
                selectedColor: AnonaColors.primeNavyAccent.withOpacity(0.25),
                checkmarkColor: AnonaColors.primeNavyAccent,
                backgroundColor: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04),
                labelStyle: TextStyle(
                  color: sel ? AnonaColors.primeNavyAccent : (isDark ? AnonaColors.silverText : AnonaColors.textSecondary),
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: BorderSide(
                    color: sel ? AnonaColors.primeNavyAccent : (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedSportsTeams.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(color: isDark ? const Color(0xFF2C2C2E) : Colors.black12, height: 1),
            const SizedBox(height: 12),
            Text('Selected (${_selectedSportsTeams.length})',
                style: TextStyle(color: isDark ? AnonaColors.silverText : AnonaColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedSportsTeams.map((t) => Chip(
                    label: Text(t,
                        style: const TextStyle(fontSize: 12, color: Colors.white)),
                    deleteIcon: const Icon(Icons.close, size: 14, color: AnonaColors.silverText),
                    onDeleted: () => _toggleTeam(t),
                    backgroundColor: AnonaColors.primeNavyMid,
                    side: BorderSide(color: AnonaColors.primeNavyAccent.withOpacity(0.4)),
                    padding: EdgeInsets.zero,
                  )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Stocks Card ───────────────────────────────────────────────────────────

  Widget _buildStocksCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark ? AnonaColors.silverText : AnonaColors.textSecondary;
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Stock Watchlist', subtitle: 'Monitor your portfolio'),
          const SizedBox(height: 14),
          // Search / add field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stockSearchController,
                  style: TextStyle(color: isDark ? Colors.white : AnonaColors.textPrimary, fontSize: 14),
                  textCapitalization: TextCapitalization.characters,
                  decoration: _glassInput('Search ticker (e.g. AAPL)',
                      suffixIcon: Icon(Icons.search, color: hintColor, size: 18)),
                  onSubmitted: (_) => _addCustomStock(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addCustomStock,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AnonaColors.moneyGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Popular defaults
          Text('Popular', style: TextStyle(color: hintColor, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: popularStocks.map((s) {
              final sel = _selectedStocks.contains(s);
              return FilterChip(
                label: Text(s),
                selected: sel,
                onSelected: (_) => _toggleStock(s),
                selectedColor: AnonaColors.moneyGreen.withOpacity(0.2),
                checkmarkColor: AnonaColors.moneyGreenLight,
                backgroundColor: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04),
                labelStyle: TextStyle(
                  color: sel ? AnonaColors.moneyGreenLight : (isDark ? AnonaColors.silverText : AnonaColors.textSecondary),
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: BorderSide(
                    color: sel ? AnonaColors.moneyGreenLight : (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                  ),
                ),
              );
            }).toList(),
          ),
          // Selected custom stocks not in popularStocks
          if (_selectedStocks.any((s) => !popularStocks.contains(s))) ...[
            const SizedBox(height: 12),
            Divider(color: isDark ? const Color(0xFF2C2C2E) : Colors.black12, height: 1),
            const SizedBox(height: 10),
            Text('Custom (${_selectedStocks.where((s) => !popularStocks.contains(s)).length})',
                style: TextStyle(color: hintColor, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedStocks.where((s) => !popularStocks.contains(s)).map((s) => Chip(
                    label: Text(s, style: const TextStyle(fontSize: 12, color: AnonaColors.moneyGreenLight, fontWeight: FontWeight.w700)),
                    deleteIcon: const Icon(Icons.close, size: 14, color: AnonaColors.silverText),
                    onDeleted: () => _toggleStock(s),
                    backgroundColor: AnonaColors.moneyGreen.withOpacity(0.12),
                    side: BorderSide(color: AnonaColors.moneyGreen.withOpacity(0.4)),
                    padding: EdgeInsets.zero,
                  )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sticky Save Bar ───────────────────────────────────────────────────────

  Widget _buildStickyBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.7),
            border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05))),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
          child: FilledButton(
            onPressed: _isSaving ? null : _saveChanges,
            style: FilledButton.styleFrom(
              backgroundColor: AnonaColors.moneyGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ),
    );
  }
}
