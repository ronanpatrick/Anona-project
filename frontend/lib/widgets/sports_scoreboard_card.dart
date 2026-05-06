import 'package:flutter/material.dart';

import '../models/sports_scoreboard.dart';
import '../screens/profile_screen.dart';

class SportsScoreboardCard extends StatelessWidget {
  const SportsScoreboardCard({
    required this.scoreboard,
    required this.isLoading,
    super.key,
  });

  final SportsScoreboard? scoreboard;
  final bool isLoading;

  static const Color _backgroundColor = Color(0xFF0D1B2A);
  static const Color _surfaceColor = Color(0xFF1A2B44);
  static const Color _silverText = Color(0xFFC8D1DB);
  static const Color _livePillColor = Color(0xFFFF6D00);

  @override
  Widget build(BuildContext context) {
    final current = scoreboard;
    return Container(
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sports_score,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Unified Sports Scoreboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _trackedGamesLabel(current),
                            style: const TextStyle(
                              color: _silverText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 36,
                height: 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading && current == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              ),
            )
          else if (current == null || !current.hasAnyGames)
            const Text(
              'No sports games available right now.',
              style: TextStyle(color: _silverText),
            )
          else
            _buildSections(current),
        ],
      ),
    );
  }

  String _trackedGamesLabel(SportsScoreboard? value) {
    if (value == null) {
      return 'Loading games...';
    }
    var count = value.yourTeams.length;
    for (final games in value.bySport.values) {
      count += games.length;
    }
    return '$count games tracked';
  }

  Widget _buildSections(SportsScoreboard value) {
    final sections = <Widget>[];
    if (value.yourTeams.isNotEmpty) {
      sections.add(_buildSectionHeader('Your Games'));
      sections.add(_buildGamesList(value.yourTeams));
    }

    for (final entry in value.bySport.entries) {
      final games = entry.value;
      if (games.isEmpty) {
        continue;
      }
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 10));
      }
      sections.add(_buildSportHeader(entry.key.toUpperCase()));
      sections.add(_buildGamesList(games));
    }

    if (sections.isEmpty) {
      return const Text(
        'No sports games available right now.',
        style: TextStyle(color: _silverText),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSportHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.62),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGamesList(List<SportsScoreboardGame> games) {
    return Column(
      children: List<Widget>.generate(games.length, (int index) {
        final game = games[index];
        return Column(
          children: <Widget>[
            if (index > 0)
              Divider(
                height: 14,
                color: Colors.white.withOpacity(0.15),
              ),
            _buildGameRow(game),
          ],
        );
      }),
    );
  }

  Widget _buildGameRow(SportsScoreboardGame game) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              _buildLogo(game.awayLogo),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${game.awayTeam} vs. ${game.homeTeam}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildLogo(game.homeLogo),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          '|',
          style: TextStyle(color: _silverText),
        ),
        const SizedBox(width: 10),
        Text(
          '${game.awayScore} - ${game.homeScore}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 10),
        _buildStatusPill(game),
      ],
    );
  }

  Widget _buildLogo(String? logoUrl) {
    final parsed = logoUrl == null ? null : Uri.tryParse(logoUrl);
    final hasLogo = parsed != null && parsed.hasScheme && parsed.host.isNotEmpty;
    return ClipOval(
      child: Container(
        width: 20,
        height: 20,
        color: _surfaceColor,
        child: hasLogo
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.shield,
                  size: 12,
                  color: _silverText,
                ),
              )
            : const Icon(
                Icons.shield,
                size: 12,
                color: _silverText,
              ),
      ),
    );
  }

  Widget _buildStatusPill(SportsScoreboardGame game) {
    final isLive = game.state == 'live';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLive ? _livePillColor : Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isLive ? 'LIVE' : game.status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
