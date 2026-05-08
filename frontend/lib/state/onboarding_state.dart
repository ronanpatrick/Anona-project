import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Topic options ──────────────────────────────────────────────────────────────
const List<String> onboardingTopics = <String>[
  'Tech',
  'Business',
  'Science',
  'Health',
  'Politics',
  'World',
];

// ── Publisher sources (all selected by default) ────────────────────────────────
const List<String> onboardingSources = <String>[
  'Reuters',
  'AP News',
  'BBC',
  'WSJ',
  'NYT',
  'Fox News',
  'CNN',
  'Bloomberg',
  'The Guardian',
  'Al Jazeera',
  'CNBC',
  'NPR',
];

// ── Sports: League → Teams map ─────────────────────────────────────────────────
const List<String> sportsLeagues = ['NBA', 'NFL', 'MLB', 'NHL', 'EPL'];

const Map<String, List<String>> leagueTeams = {
  'NBA': [
    'Los Angeles Lakers', 'Golden State Warriors', 'Boston Celtics',
    'Miami Heat', 'Chicago Bulls', 'Brooklyn Nets',
    'Dallas Mavericks', 'Denver Nuggets', 'Phoenix Suns',
    'Milwaukee Bucks', 'Toronto Raptors', 'New York Knicks',
  ],
  'NFL': [
    'Kansas City Chiefs', 'San Francisco 49ers', 'Dallas Cowboys',
    'New England Patriots', 'Green Bay Packers', 'Philadelphia Eagles',
    'Buffalo Bills', 'Baltimore Ravens', 'Las Vegas Raiders',
    'Los Angeles Rams', 'Seattle Seahawks', 'Miami Dolphins',
  ],
  'MLB': [
    'New York Yankees', 'Los Angeles Dodgers', 'Boston Red Sox',
    'Chicago Cubs', 'Houston Astros', 'Atlanta Braves',
    'San Francisco Giants', 'St. Louis Cardinals', 'New York Mets',
    'Toronto Blue Jays', 'Philadelphia Phillies', 'Seattle Mariners',
  ],
  'NHL': [
    'Toronto Maple Leafs', 'Montreal Canadiens', 'Boston Bruins',
    'New York Rangers', 'Colorado Avalanche', 'Vegas Golden Knights',
    'Chicago Blackhawks', 'Edmonton Oilers', 'Pittsburgh Penguins',
    'Tampa Bay Lightning', 'Detroit Red Wings', 'Dallas Stars',
  ],
  'EPL': [
    'Arsenal', 'Chelsea', 'Liverpool',
    'Manchester City', 'Manchester United', 'Tottenham Hotspur',
    'Newcastle United', 'Aston Villa', 'Brighton & Hove Albion',
    'West Ham United', 'Everton', 'Leicester City',
  ],
};

// ── Popular stock tickers ──────────────────────────────────────────────────────
const List<String> popularStocks = [
  'AAPL', 'MSFT', 'TSLA', 'NVDA', 'AMZN',
  'GOOGL', 'META', 'BRK.B', '^GSPC', '^DJI',
  'NFLX', 'AMD', 'UBER', 'JPM', 'V',
];

// ── AI Personality ─────────────────────────────────────────────────────────────
enum AiPersonality {
  executive,
  analyst,
  conversationalist,
  layman;

  String get label {
    switch (this) {
      case AiPersonality.executive:
        return 'The Executive';
      case AiPersonality.analyst:
        return 'The Analyst';
      case AiPersonality.conversationalist:
        return 'The Conversationalist';
      case AiPersonality.layman:
        return 'The Layman';
    }
  }

  String get subtitle {
    switch (this) {
      case AiPersonality.executive:
        return 'Concise, bullet-driven briefs';
      case AiPersonality.analyst:
        return 'Deep context & nuance';
      case AiPersonality.conversationalist:
        return 'Podcast-style narrative';
      case AiPersonality.layman:
        return 'Plain, simple language';
    }
  }

  IconData get icon {
    switch (this) {
      case AiPersonality.executive:
        return Icons.bolt_rounded;
      case AiPersonality.analyst:
        return Icons.analytics_outlined;
      case AiPersonality.conversationalist:
        return Icons.mic_none_rounded;
      case AiPersonality.layman:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  String get dbValue {
    switch (this) {
      case AiPersonality.executive:
        return 'executive';
      case AiPersonality.analyst:
        return 'professional';  // backend ToneType uses 'professional'
      case AiPersonality.conversationalist:
        return 'conversationalist';
      case AiPersonality.layman:
        return 'layman';
    }
  }
}

// ── SummaryTone ────────────────────────────────────────────────────────────────
enum SummaryTone {
  executive,
  analyst,
  conversationalist,
  layman;

  String get dbValue {
    switch (this) {
      case SummaryTone.executive:
        return 'executive';
      case SummaryTone.analyst:
        return 'professional';  // backend ToneType uses 'professional'
      case SummaryTone.conversationalist:
        return 'conversationalist';
      case SummaryTone.layman:
        return 'layman';
    }
  }

  String get label {
    switch (this) {
      case SummaryTone.executive:
        return 'Executive';
      case SummaryTone.analyst:
        return 'Analyst';
      case SummaryTone.conversationalist:
        return 'Conversationalist';
      case SummaryTone.layman:
        return 'Layman';
    }
  }

  String get subtitle {
    switch (this) {
      case SummaryTone.executive:
        return 'Concise, bullet-driven briefs';
      case SummaryTone.analyst:
        return 'Deep context & nuance';
      case SummaryTone.conversationalist:
        return 'Podcast-style narrative';
      case SummaryTone.layman:
        return 'Plain, simple language';
    }
  }

  IconData get icon {
    switch (this) {
      case SummaryTone.executive:
        return Icons.bolt_rounded;
      case SummaryTone.analyst:
        return Icons.analytics_outlined;
      case SummaryTone.conversationalist:
        return Icons.mic_none_rounded;
      case SummaryTone.layman:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  static SummaryTone fromDbValue(String? value) {
    switch (value) {
      case 'executive':
        return SummaryTone.executive;
      case 'conversationalist':
        return SummaryTone.conversationalist;
      case 'layman':
        return SummaryTone.layman;
      case 'professional':
      case 'analyst':
      default:
        return SummaryTone.analyst;
    }
  }
}

enum SourceControlPreference { allow, block }

// ── Onboarding State ───────────────────────────────────────────────────────────
class OnboardingState {
  const OnboardingState({
    this.firstName = '',
    this.topics = const <String>[],
    this.selectedSources = onboardingSources,
    this.aiPersonality = AiPersonality.executive,
    this.stockTickers = const <String>[],
    this.sportsTeams = const <String>[],
    this.briefingTime = '08:00',
    // Legacy fields kept for auth_service compatibility
    this.lifeTracking = const <String>[],
    this.sourceControl = SourceControlPreference.allow,
    this.summaryTone = SummaryTone.analyst,
  });

  final String firstName;
  final List<String> topics;
  final List<String> selectedSources;
  final AiPersonality aiPersonality;
  final List<String> stockTickers;
  final List<String> sportsTeams;
  final String briefingTime;

  // Legacy
  final List<String> lifeTracking;
  final SourceControlPreference sourceControl;
  final SummaryTone summaryTone;

  OnboardingState copyWith({
    String? firstName,
    List<String>? topics,
    List<String>? selectedSources,
    AiPersonality? aiPersonality,
    List<String>? stockTickers,
    List<String>? sportsTeams,
    String? briefingTime,
    List<String>? lifeTracking,
    SourceControlPreference? sourceControl,
    SummaryTone? summaryTone,
  }) {
    return OnboardingState(
      firstName: firstName ?? this.firstName,
      topics: topics ?? this.topics,
      selectedSources: selectedSources ?? this.selectedSources,
      aiPersonality: aiPersonality ?? this.aiPersonality,
      stockTickers: stockTickers ?? this.stockTickers,
      sportsTeams: sportsTeams ?? this.sportsTeams,
      briefingTime: briefingTime ?? this.briefingTime,
      lifeTracking: lifeTracking ?? this.lifeTracking,
      sourceControl: sourceControl ?? this.sourceControl,
      summaryTone: summaryTone ?? this.summaryTone,
    );
  }
}

// ── Onboarding Controller ──────────────────────────────────────────────────────
class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController() : super(const OnboardingState());

  void setFirstName(String name) {
    state = state.copyWith(firstName: name);
  }

  void toggleTopic(String topic) {
    final next = List<String>.from(state.topics);
    if (next.contains(topic)) {
      next.remove(topic);
    } else {
      next.add(topic);
    }
    state = state.copyWith(topics: next);
  }

  void toggleSource(String source) {
    final next = List<String>.from(state.selectedSources);
    if (next.contains(source)) {
      next.remove(source);
    } else {
      next.add(source);
    }
    state = state.copyWith(selectedSources: next);
  }

  void setAiPersonality(AiPersonality personality) {
    state = state.copyWith(aiPersonality: personality);
  }

  void addStockTicker(String ticker) {
    final t = ticker.trim().toUpperCase();
    if (t.isEmpty) return;
    final next = List<String>.from(state.stockTickers);
    if (!next.contains(t)) next.add(t);
    state = state.copyWith(stockTickers: next);
  }

  void removeStockTicker(String ticker) {
    final next = List<String>.from(state.stockTickers)..remove(ticker);
    state = state.copyWith(stockTickers: next);
  }

  void addSportsTeam(String team) {
    final t = team.trim();
    if (t.isEmpty) return;
    final next = List<String>.from(state.sportsTeams);
    if (!next.contains(t)) next.add(t);
    state = state.copyWith(sportsTeams: next);
  }

  void removeSportsTeam(String team) {
    final next = List<String>.from(state.sportsTeams)..remove(team);
    state = state.copyWith(sportsTeams: next);
  }

  void setBriefingTime(String value) {
    state = state.copyWith(briefingTime: value);
  }

  // Legacy
  void toggleLifeTracking(String item) {
    final next = List<String>.from(state.lifeTracking);
    if (next.contains(item)) {
      next.remove(item);
    } else {
      next.add(item);
    }
    state = state.copyWith(lifeTracking: next);
  }

  void setSourceControl(SourceControlPreference value) {
    state = state.copyWith(sourceControl: value);
  }

  void setSummaryTone(SummaryTone value) {
    state = state.copyWith(summaryTone: value);
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  return OnboardingController();
});
