import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sports_scoreboard.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

class SportsScoreboardCard extends StatelessWidget {
  const SportsScoreboardCard({
    required this.scoreboard,
    required this.isLoading,
    this.onTap,
    this.isExpanded = false,
    super.key,
  });

  final SportsScoreboard? scoreboard;
  final bool isLoading;
  final VoidCallback? onTap;
  final bool isExpanded;

  // Brand tokens
  static const Color _cardBg    = AnonaColors.primeNavy;
  static const Color _surface   = AnonaColors.primeNavyMid;
  static const Color _accent    = AnonaColors.primeNavyAccent;
  static const Color _silver    = AnonaColors.silverText;
  static const Color _liveColor = AnonaColors.liveOrange;

  @override
  Widget build(BuildContext context) {
    final current = scoreboard;
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sports_score_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Scoreboard',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      _trackedGamesLabel(current),
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.12), height: 1),
          const SizedBox(height: 10),

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
                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5)),
              ),
            )
          else
            if (isExpanded)
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: _buildSections(current),
                ),
              )
            else
              _buildSections(current),
        ],
      );

    Widget card = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF07101A), _cardBg, _surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: isExpanded
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.3),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: content,
    );

    if (onTap != null && !isExpanded) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
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
    int displayedGames = 0;

    if (value.yourTeams.isNotEmpty) {
      final gamesToShow = isExpanded ? value.yourTeams : value.yourTeams.take(3).toList();
      if (gamesToShow.isNotEmpty) {
        sections
          ..add(_sectionLabel('YOUR GAMES'))
          ..add(_buildGamesList(gamesToShow));
        displayedGames += gamesToShow.length;
      }
    }

    for (final entry in value.bySport.entries) {
      if (!isExpanded && displayedGames >= 3) break;
      if (entry.value.isEmpty) continue;
      final gamesToShow = isExpanded ? entry.value : entry.value.take(3 - displayedGames).toList();
      if (gamesToShow.isNotEmpty) {
        if (sections.isNotEmpty) sections.add(const SizedBox(height: 14));
        sections
          ..add(_sectionLabel(entry.key.toUpperCase()))
          ..add(_buildGamesList(gamesToShow));
        displayedGames += gamesToShow.length;
      }
    }

    if (sections.isEmpty) {
      return Text('No games available.',
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5)));
    }

    int totalGames = value.yourTeams.length;
    for (final list in value.bySport.values) {
      totalGames += list.length;
    }

    if (!isExpanded && totalGames > 3) {
      sections.add(const SizedBox(height: 14));
      sections.add(GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'View all $totalGames games',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: sections);
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
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
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(
        children: List.generate(games.length, (i) {
          return Column(
            children: [
              if (i > 0)
                Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.08),
                    indent: 0,
                    endIndent: 0),
              _buildGameRow(games[i]),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildGameRow(SportsScoreboardGame game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          // ── Left: away logo + team names ───────────────────────────────
          Expanded(
            child: Row(
              children: [
                _buildLogo(game.awayLogo),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.awayTeam,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'vs. ${game.homeTeam}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Right: home logo + score + status (fixed width) ────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLogo(game.homeLogo),
              const SizedBox(width: 8),
              Text(
                '${game.awayScore}–${game.homeScore}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(game),
            ],
          ),
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
        color: isLive ? _liveColor.withOpacity(0.2) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: isLive ? Border.all(color: _liveColor.withOpacity(0.4), width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Icon(Icons.sensors, color: _liveColor, size: 9),
            const SizedBox(width: 2),
          ],
          Text(
            isLive ? 'LIVE' : game.status,
            style: GoogleFonts.inter(
              color: isLive ? _liveColor : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

