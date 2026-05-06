import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../state/onboarding_state.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.onCompleted});

  final VoidCallback? onCompleted;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep >= 2) {
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _previousStep() {
    if (_currentStep <= 0) {
      return;
    }
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    final onboarding = ref.read(onboardingProvider);
    if (onboarding.topics.isEmpty) {
      setState(() {
        _error = 'Select at least one topic to continue.';
      });
      return;
    }

    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Your session expired. Please sign in again.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await authService.saveUserPreferences(
        userId: user.id,
        preferences: onboarding,
      );
      if (!mounted) {
        return;
      }
      widget.onCompleted?.call();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Unable to save preferences: $error';
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);
    final isLastStep = _currentStep == 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Anona')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: LinearProgressIndicator(value: (_currentStep + 1) / 3),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                children: <Widget>[
                  _StepScaffold(
                    title: 'Step 1: Choose your topics',
                    subtitle: 'Pick what you want in your daily digest.',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: onboardingTopics
                          .map(
                            (topic) => FilterChip(
                              label: Text(topic),
                              selected: onboarding.topics.contains(topic),
                              onSelected: (_) => controller.toggleTopic(topic),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  _StepScaffold(
                    title: 'Step 2: Pick your summary tone',
                    subtitle: 'Set how article summaries should sound.',
                    child: SegmentedButton<SummaryTone>(
                      segments: SummaryTone.values
                          .map(
                            (tone) => ButtonSegment<SummaryTone>(
                              value: tone,
                              label: Text(tone.label),
                            ),
                          )
                          .toList(growable: false),
                      selected: <SummaryTone>{onboarding.summaryTone},
                      onSelectionChanged: (selection) {
                        controller.setSummaryTone(selection.first);
                      },
                    ),
                  ),
                  _StepScaffold(
                    title: 'Step 3: Finish setup',
                    subtitle: 'Save preferences and start your briefing.',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: Text(
                        'Topics: ${onboarding.topics.join(', ')}\nTone: ${onboarding.summaryTone.label}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: _isSaving || _currentStep == 0 ? null : _previousStep,
                    child: const Text('Back'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : isLastStep
                            ? _finish
                            : _nextStep,
                    child: Text(
                      _isSaving
                          ? 'Saving...'
                          : isLastStep
                              ? 'Finish'
                              : 'Next',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(subtitle),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
