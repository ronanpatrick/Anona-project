import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SummaryTone {
  professional,
  casual,
  explainLikeIm5;

  String get dbValue {
    switch (this) {
      case SummaryTone.professional:
        return 'professional';
      case SummaryTone.casual:
        return 'casual';
      case SummaryTone.explainLikeIm5:
        return 'explain_like_im_5';
    }
  }

  String get label {
    switch (this) {
      case SummaryTone.professional:
        return 'Professional';
      case SummaryTone.casual:
        return 'Casual';
      case SummaryTone.explainLikeIm5:
        return "Explain like I'm 5";
    }
  }
}

enum SourceControlPreference { allow, block }

class OnboardingState {
  const OnboardingState({
    this.topics = const <String>[],
    this.lifeTracking = const <String>[],
    this.sourceControl = SourceControlPreference.allow,
    this.summaryTone = SummaryTone.professional,
    this.briefingTime = '08:00',
  });

  final List<String> topics;
  final List<String> lifeTracking;
  final SourceControlPreference sourceControl;
  final SummaryTone summaryTone;
  final String briefingTime;

  OnboardingState copyWith({
    List<String>? topics,
    List<String>? lifeTracking,
    SourceControlPreference? sourceControl,
    SummaryTone? summaryTone,
    String? briefingTime,
  }) {
    return OnboardingState(
      topics: topics ?? this.topics,
      lifeTracking: lifeTracking ?? this.lifeTracking,
      sourceControl: sourceControl ?? this.sourceControl,
      summaryTone: summaryTone ?? this.summaryTone,
      briefingTime: briefingTime ?? this.briefingTime,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController() : super(const OnboardingState());

  void toggleTopic(String topic) {
    final next = List<String>.from(state.topics);
    if (next.contains(topic)) {
      next.remove(topic);
    } else {
      next.add(topic);
    }
    state = state.copyWith(topics: next);
  }

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

  void setBriefingTime(String value) {
    state = state.copyWith(briefingTime: value);
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  return OnboardingController();
});
