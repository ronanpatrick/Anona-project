import 'package:flutter/material.dart';

import '../models/sports_scoreboard.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

class SportsScoreboardCard extends StatelessWidget {
  const SportsScoreboardCard({
    required this.scoreboard,
    required this.isLoading,
    super.key,
  });

  final SportsScoreboard? scoreboard;
  final bool isLoading;

  // Brand tokens
  static const Color _cardBg    = AnonaColors.primeNavy;
  static const Color _surface   = AnonaColors.primeNavyMid;
  static const Color _accent    = AnonaColors.primeNavyAccent;
  static const Color _silver    = AnonaColors.silverText;
  static const Color _liveColor = AnonaColors.liveOrange;

  @override
  Widget build(BuildContext context) {
    final current = scoreboard;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF07101A), _cardBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _cardBg.withOpacity(0.5),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sports_score_rounded,
                    color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Scoreboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      _trackedGamesLabel(current),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
              _GlassBtn(
                icon: Icons.tune_rounded,
                color: _accent,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const ProfileScreen()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          const SizedBox(height: 12),

          if (isLoading && current == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else if (current == null || !current.hasAnyGames)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No games right now. Check back later.',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            )
          else
            _buildSections(current),
        ],
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  String _trackedGamesLabel(SportsScoreboard? v) {
    if (v == null) return 'Loading…';
    var count = v.yourTeams.length;
    for (final g in v.bySport.values) { count += g.length; }
    return '$count games tracked';
  }

  Widget _buildSections(SportsScoreboard value) {
    final sections = <Widget>[];

    if (value.yourTeams.isNotEmpty) {
      sections
        ..add(_sectionLabel('YOUR GAMES'))
        ..add(_buildGamesList(value.yourTeams));
    }

    for (final entry in value.bySport.entries) {
      if (entry.value.isEmpty) continue;
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 12));
      sections
        ..add(_sectionLabel(entry.key.toUpperCase()))
        ..add(_buildGamesList(entry.value));
    }

    if (sections.isEmpty) {
      return Text('No games available.',
          style: TextStyle(color: Colors.white.withOpacity(0.5)));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: sections);
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: _accent.withOpacity(0.8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildGamesList(List<SportsScoreboardGame> games) {
    return Container(
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(games.length, (i) {
          return Column(
            children: [
              if (i > 0)
                Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.07),
                    indent: 14,
                    endIndent: 14),
              _buildGameRow(games[i]),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildGameRow(SportsScoreboardGame game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          _buildLogo(game.awayLogo),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${game.awayTeam}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'vs. ${game.homeTeam}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 11),
                ),
              ],
            ),
          ),
          _buildLogo(game.homeLogo),
          const SizedBox(width: 10),
          // Score
          Text(
            '${game.awayScore} – ${game.homeScore}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusPill(game),
        ],
      ),
    );
  }

  Widget _buildLogo(String? logoUrl) {
    final parsed = logoUrl == null ? null : Uri.tryParse(logoUrl);
    final hasLogo = parsed != null && parsed.hasScheme && parsed.host.isNotEmpty;
    return ClipOval(
      child: Container(
        width: 24,
        height: 24,
        color: _surface,
        child: hasLogo
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.shield, size: 13, color: _silver),
              )
            : const Icon(Icons.shield, size: 13, color: _silver),
      ),
    );
  }

  Widget _buildStatusPill(SportsScoreboardGame game) {
    final isLive = game.state == 'live';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLive ? _liveColor : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            isLive ? 'LIVE' : game.status,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Sub-widget ────────────────────────────────────────────────────────────────
class _GlassBtn extends StatelessWidget {
  const _GlassBtn({
      required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}
