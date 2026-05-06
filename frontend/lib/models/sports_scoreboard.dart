class SportsScoreboardGame {
  const SportsScoreboardGame({
    required this.sport,
    required this.eventId,
    required this.awayTeam,
    required this.awayScore,
    required this.homeTeam,
    required this.homeScore,
    required this.status,
    required this.state,
    this.awayLogo,
    this.homeLogo,
    this.startTime,
  });

  final String sport;
  final String eventId;
  final String awayTeam;
  final String? awayLogo;
  final String awayScore;
  final String homeTeam;
  final String? homeLogo;
  final String homeScore;
  final String status;
  final String state;
  final String? startTime;

  factory SportsScoreboardGame.fromJson(Map<String, dynamic> json) {
    return SportsScoreboardGame(
      sport: (json['sport'] as String? ?? '').trim(),
      eventId: (json['event_id'] as String? ?? '').trim(),
      awayTeam: (json['away_team'] as String? ?? '').trim(),
      awayLogo: _parseOptionalString(json['away_logo']),
      awayScore: (json['away_score'] as String? ?? '0').trim(),
      homeTeam: (json['home_team'] as String? ?? '').trim(),
      homeLogo: _parseOptionalString(json['home_logo']),
      homeScore: (json['home_score'] as String? ?? '0').trim(),
      status: (json['status'] as String? ?? 'Scheduled').trim(),
      state: (json['state'] as String? ?? 'upcoming').trim().toLowerCase(),
      startTime: _parseOptionalString(json['start_time']),
    );
  }

  static String? _parseOptionalString(dynamic value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class SportsScoreboard {
  const SportsScoreboard({
    required this.yourTeams,
    required this.bySport,
  });

  final List<SportsScoreboardGame> yourTeams;
  final Map<String, List<SportsScoreboardGame>> bySport;

  factory SportsScoreboard.fromJson(Map<String, dynamic> json) {
    final yourTeamsRaw = json['your_teams'];
    final yourTeams = _parseGames(yourTeamsRaw);

    final bySport = <String, List<SportsScoreboardGame>>{};
    for (final entry in json.entries) {
      if (entry.key == 'your_teams') {
        continue;
      }
      bySport[entry.key] = _parseGames(entry.value);
    }

    return SportsScoreboard(yourTeams: yourTeams, bySport: bySport);
  }

  static List<SportsScoreboardGame> _parseGames(dynamic value) {
    if (value is! List) {
      return <SportsScoreboardGame>[];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(SportsScoreboardGame.fromJson)
        .toList(growable: false);
  }

  bool get hasAnyGames {
    if (yourTeams.isNotEmpty) {
      return true;
    }
    for (final games in bySport.values) {
      if (games.isNotEmpty) {
        return true;
      }
    }
    return false;
  }
}
