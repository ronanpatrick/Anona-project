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
    return _client.from('user_preferences').upsert(
      <String, dynamic>{
        'id': userId,
        'first_name': preferences.firstName,
        'selected_topics': preferences.topics,
        'whitelisted_sources': preferences.selectedSources,
        'summary_tone': preferences.aiPersonality.dbValue,
        'stock_tickers': preferences.stockTickers,
        'sports_teams': preferences.sportsTeams,
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
          .select('selected_topics')
          .eq('id', userId)
          .maybeSingle();

      if (row == null) return false;
      
      final topics = row['selected_topics'];
      if (topics == null) return false;
      if (topics is List && topics.isEmpty) return false;
      
      return true;
    } catch (e) {
      print('Supabase Error: $e');
      return false;
    }
  }
}
