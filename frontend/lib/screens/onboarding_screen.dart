import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../state/onboarding_state.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _topics = <String>[
    'Technology',
    'Business',
    'Science',
    'Politics',
    'Health',
    'Culture',
  ];

  static const _lifeTrackingItems = <String>['Stocks', 'Sports'];

  int _step = 0;
  bool _isSaving = false;
  String? _error;

  Future<void> _pickTime(OnboardingController controller, String current) async {
    final parts = current.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: int.tryParse(parts.last) ?? 0,
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (selected == null) {
      return;
    }
    final hh = selected.hour.toString().padLeft(2, '0');
    final mm = selected.minute.toString().padLeft(2, '0');
    controller.setBriefingTime('$hh:$mm');
  }

  Future<void> _complete() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) {
      setState(() {
        _isSaving = false;
        _error = 'You need to sign in again.';
      });
      return;
    }

    try {
      await authService.saveUserPreferences(
        userId: user.id,
        preferences: ref.read(onboardingProvider),
      );
      if (!mounted) {
        return;
      }
      context.go('/home');
    } on PostgrestException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Unable to save preferences right now.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onboarding = ref.watch(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);
    final isFinalStep = _step == 5;

    return Scaffold(
      appBar: AppBar(title: const Text('Setup your briefing')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(value: (_step + 1) / 6),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildStepContent(
                          step: _step,
                          state: onboarding,
                          controller: controller,
                          theme: theme,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (_step > 0)
                            TextButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => setState(() => _step -= 1),
                              child: const Text('Back'),
                            ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    if (isFinalStep) {
                                      _complete();
                                      return;
                                    }
                                    setState(() => _step += 1);
                                  },
                            child: Text(
                              _isSaving
                                  ? 'Saving...'
                                  : (isFinalStep ? 'Complete setup' : 'Next'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent({
    required int step,
    required OnboardingState state,
    required OnboardingController controller,
    required ThemeData theme,
  }) {
    switch (step) {
      case 0:
        return _StepLayout(
          title: 'What topics should lead your feed?',
          subtitle: 'Select the areas you care about most.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in _topics)
                FilterChip(
                  label: Text(topic),
                  selected: state.topics.contains(topic),
                  onSelected: (_) => controller.toggleTopic(topic),
                ),
            ],
          ),
        );
      case 1:
        return _StepLayout(
          title: 'What should we track in your daily life?',
          subtitle: 'Enable optional quick tracking modules.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in _lifeTrackingItems)
                FilterChip(
                  label: Text(item),
                  selected: state.lifeTracking.contains(item),
                  onSelected: (_) => controller.toggleLifeTracking(item),
                ),
            ],
          ),
        );
      case 2:
        return _StepLayout(
          title: 'How should source filtering work?',
          subtitle: 'Choose whether your source list defaults to allow or block.',
          child: SegmentedButton<SourceControlPreference>(
            segments: const [
              ButtonSegment(
                value: SourceControlPreference.allow,
                label: Text('Allow list'),
              ),
              ButtonSegment(
                value: SourceControlPreference.block,
                label: Text('Block list'),
              ),
            ],
            selected: <SourceControlPreference>{state.sourceControl},
            onSelectionChanged: (value) => controller.setSourceControl(
              value.first,
            ),
          ),
        );
      case 3:
        return _StepLayout(
          title: 'Pick your summary tone',
          subtitle: 'You can change this later in settings.',
          child: SegmentedButton<SummaryTone>(
            segments: SummaryTone.values
                .map(
                  (tone) => ButtonSegment<SummaryTone>(
                    value: tone,
                    label: Text(tone.label),
                  ),
                )
                .toList(),
            selected: <SummaryTone>{state.summaryTone},
            onSelectionChanged: (value) => controller.setSummaryTone(value.first),
          ),
        );
      case 4:
        return _StepLayout(
          title: 'When should your briefing arrive?',
          subtitle: 'Choose your preferred daily briefing time.',
          child: OutlinedButton.icon(
            onPressed: () => _pickTime(controller, state.briefingTime),
            icon: const Icon(Icons.schedule),
            label: Text('Briefing time: ${state.briefingTime}'),
          ),
        );
      default:
        return _StepLayout(
          title: 'You are all set',
          subtitle:
              'Anona will now generate a focused daily briefing based on your topics, life tracking, source control, and tone preferences.',
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'From Home, you can read your briefing, save summaries, and tune preferences any time.',
            ),
          ),
        );
    }
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(subtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 18),
        child,
      ],
    );
  }
}
