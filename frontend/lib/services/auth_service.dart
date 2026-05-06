import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/onboarding_state.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(Supabase.instance.client);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final hasCompletedOnboardingProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  return ref.watch(authServiceProvider).hasCompletedOnboarding(userId);
});

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  Future<void> saveUserPreferences({
    required String userId,
    required OnboardingState preferences,
  }) {
    final stockTickers = preferences.lifeTracking
        .where((item) => item.toLowerCase().contains('stock'))
        .toList();
    final sportsTeams = preferences.lifeTracking
        .where((item) => item.toLowerCase().contains('sport'))
        .toList();
    final whitelistedSources = <String>[];
    final blacklistedSources = <String>[];

    return _client.from('user_preferences').upsert(
      <String, dynamic>{
        'id': userId,
        'selected_topics': preferences.topics,
        'sports_teams': sportsTeams,
        'stock_tickers': stockTickers,
        'whitelisted_sources': whitelistedSources,
        'blacklisted_sources': blacklistedSources,
        'summary_tone': preferences.summaryTone.dbValue,
        'briefing_time': preferences.briefingTime,
        'onboarding_completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'id',
    );
  }

  Future<bool> hasCompletedOnboarding(String userId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || currentUser.id != userId) {
      return false;
    }

    try {
      final row = await _client
          .from('user_preferences')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      return row != null;
    } catch (e) {
      print('Supabase Error: $e');
      return false;
    }
  }
}
