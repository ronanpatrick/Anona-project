import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionState {
  const SessionState({
    this.isAuthenticated = false,
    this.preference = 'balanced',
  });

  final bool isAuthenticated;
  final String preference;

  SessionState copyWith({
    bool? isAuthenticated,
    String? preference,
  }) {
    return SessionState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      preference: preference ?? this.preference,
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  SessionController() : super(const SessionState());

  void setAuthenticated(bool value) {
    state = state.copyWith(isAuthenticated: value);
  }

  void setPreference(String value) {
    state = state.copyWith(preference: value);
  }
}

final sessionProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController();
});

