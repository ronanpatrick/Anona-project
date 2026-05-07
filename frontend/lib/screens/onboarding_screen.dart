import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../state/onboarding_state.dart';
import '../theme/app_theme.dart';

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
  final int _totalSteps = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishSetup() async {
    final onboardingState = ref.read(onboardingProvider);
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;

    // Perform the actual Supabase update via authService
    if (user != null) {
      setState(() => _isSaving = true);
      try {
        await authService.saveUserPreferences(
          userId: user.id,
          preferences: onboardingState,
        );
        if (mounted) {
          if (widget.onCompleted != null) {
            widget.onCompleted!();
          } else {
            context.go('/home');
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save preferences: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } else {
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            _buildProgressIndicator(cs),
            
            // Pager
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable manual swipe
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _Step1Welcome(onNext: _nextStep),
                  _Step2CoreDiet(onNext: _nextStep, onBack: _previousStep),
                  _Step3SourceControl(onNext: _nextStep, onBack: _previousStep),
                  _Step4AiPersonality(onNext: _nextStep, onBack: _previousStep),
                  _Step5Dashboards(onNext: _nextStep, onBack: _previousStep),
                  _Step6Habit(
                    onComplete: _finishSetup,
                    onBack: _previousStep,
                    isSaving: _isSaving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 4,
            width: isActive ? 24 : 12,
            decoration: BoxDecoration(
              color: isActive ? cs.primary : cs.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Welcome
// ─────────────────────────────────────────────────────────────────────────────
class _Step1Welcome extends ConsumerStatefulWidget {
  const _Step1Welcome({required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<_Step1Welcome> createState() => _Step1WelcomeState();
}

class _Step1WelcomeState extends ConsumerState<_Step1Welcome> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(onboardingProvider).firstName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final firstName = ref.watch(onboardingProvider).firstName;
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(
            'Welcome to Anona.\nWhat should we call you?',
            style: tt.headlineMedium?.copyWith(height: 1.2),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 48),
          TextField(
            controller: _controller,
            onChanged: (val) => ref.read(onboardingProvider.notifier).setFirstName(val),
            style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Your First Name',
              hintStyle: tt.displaySmall?.copyWith(color: cs.onSurface.withOpacity(0.2)),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
          const Spacer(flex: 3),
          _NextButton(
            onPressed: firstName.trim().isNotEmpty ? widget.onNext : null,
          ).animate().fadeIn(delay: 600.ms),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: The Core Diet
// ─────────────────────────────────────────────────────────────────────────────
class _Step2CoreDiet extends ConsumerWidget {
  const _Step2CoreDiet({required this.onNext, required this.onBack});
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(onboardingProvider);
    final name = state.firstName.isNotEmpty ? state.firstName : 'there';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'What matters to you, $name?',
            style: tt.headlineMedium,
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 8),
          Text(
            'Select the topics you care about most.',
            style: tt.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 40),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              itemCount: onboardingTopics.length,
              itemBuilder: (context, index) {
                final topic = onboardingTopics[index];
                final isSelected = state.topics.contains(topic);
                return _TopicCard(
                  title: topic,
                  isSelected: isSelected,
                  onTap: () => ref.read(onboardingProvider.notifier).toggleTopic(topic),
                ).animate().fadeIn(delay: (200 + index * 50).ms).scale(begin: const Offset(0.9, 0.9));
              },
            ),
          ),
          _FooterActions(onNext: state.topics.isNotEmpty ? onNext : null, onBack: onBack),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.title, required this.isSelected, required this.onTap});
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected 
              ? cs.primary.withOpacity(0.1) 
              : (isDark ? cs.surfaceContainerHighest : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: isSelected ? cs.primary : cs.onSurface,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3: Source Control
// ─────────────────────────────────────────────────────────────────────────────
class _Step3SourceControl extends ConsumerWidget {
  const _Step3SourceControl({required this.onNext, required this.onBack});
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(onboardingProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Curate your news desk.',
            style: tt.headlineMedium,
          ).animate().fadeIn().slideX(begin: 0.1),
          const SizedBox(height: 8),
          Text(
            'Tap to remove sources you want to avoid.',
            style: tt.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 40),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 16,
              children: onboardingSources.map((source) {
                final isSelected = state.selectedSources.contains(source);
                return _SourceChip(
                  label: source,
                  isSelected: isSelected,
                  onTap: () => ref.read(onboardingProvider.notifier).toggleSource(source),
                ).animate().fadeIn(delay: 200.ms).scale();
              }).toList(),
            ),
          ),
          _FooterActions(onNext: onNext, onBack: onBack),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? cs.onSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? cs.onSurface : cs.outline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isSelected ? cs.surface : cs.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4: AI Personality
// ─────────────────────────────────────────────────────────────────────────────
class _Step4AiPersonality extends ConsumerWidget {
  const _Step4AiPersonality({required this.onNext, required this.onBack});
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(onboardingProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'How do you want your news delivered?',
            style: tt.headlineMedium,
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: AiPersonality.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final personality = AiPersonality.values[index];
                final isSelected = state.aiPersonality == personality;
                return _PersonalityCard(
                  personality: personality,
                  isSelected: isSelected,
                  onTap: () => ref.read(onboardingProvider.notifier).setAiPersonality(personality),
                ).animate().fadeIn(delay: (100 + index * 50).ms).slideX(begin: 0.05);
              },
            ),
          ),
          _FooterActions(onNext: onNext, onBack: onBack),
        ],
      ),
    );
  }
}

class _PersonalityCard extends StatelessWidget {
  const _PersonalityCard({
    required this.personality,
    required this.isSelected,
    required this.onTap,
  });
  
  final AiPersonality personality;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected 
              ? cs.primary.withOpacity(0.08) 
              : (isDark ? cs.surfaceContainerHighest : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(personality.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    personality.label,
                    style: tt.titleLarge?.copyWith(
                      color: isSelected ? cs.primary : cs.onSurface,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    personality.subtitle,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 28)
                  .animate().scale(curve: Curves.elasticOut),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5: The Dashboards
// ─────────────────────────────────────────────────────────────────────────────
class _Step5Dashboards extends ConsumerStatefulWidget {
  const _Step5Dashboards({required this.onNext, required this.onBack});
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  ConsumerState<_Step5Dashboards> createState() => _Step5DashboardsState();
}

class _Step5DashboardsState extends ConsumerState<_Step5Dashboards> {
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _sportsController = TextEditingController();

  void _addStock() {
    ref.read(onboardingProvider.notifier).addStockTicker(_stockController.text);
    _stockController.clear();
  }

  void _addSport() {
    ref.read(onboardingProvider.notifier).addSportsTeam(_sportsController.text);
    _sportsController.clear();
  }

  @override
  void dispose() {
    _stockController.dispose();
    _sportsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(onboardingProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Track your world.',
                  style: tt.headlineMedium,
                ).animate().fadeIn().slideY(begin: 0.1),
              ),
              TextButton(
                onPressed: widget.onNext,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                ),
                child: const Text('Skip for now'),
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stocks
                  Text('Stocks & Crypto', style: tt.titleLarge),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: _stockController,
                    hint: 'e.g. AAPL, BTC',
                    onSubmitted: (_) => _addStock(),
                    icon: Icons.show_chart_rounded,
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: state.stockTickers.map((t) => _DeletableChip(
                      label: t,
                      onDeleted: () => ref.read(onboardingProvider.notifier).removeStockTicker(t),
                    )).toList(),
                  ),
                  const SizedBox(height: 40),
                  
                  // Sports
                  Text('Sports Teams', style: tt.titleLarge),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: _sportsController,
                    hint: 'e.g. Lakers, Arsenal',
                    onSubmitted: (_) => _addSport(),
                    icon: Icons.sports_basketball_rounded,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: state.sportsTeams.map((t) => _DeletableChip(
                      label: t,
                      onDeleted: () => ref.read(onboardingProvider.notifier).removeSportsTeam(t),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          _FooterActions(onNext: widget.onNext, onBack: widget.onBack),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller, 
    required String hint, 
    required Function(String) onSubmitted,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        prefixIcon: Icon(icon, color: cs.onSurfaceVariant),
        suffixIcon: IconButton(
          icon: Icon(Icons.add_circle_rounded, color: cs.primary),
          onPressed: () => onSubmitted(controller.text),
        ),
        filled: true,
        fillColor: isDark ? cs.surfaceContainerHighest : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

class _DeletableChip extends StatelessWidget {
  const _DeletableChip({required this.label, required this.onDeleted});
  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onDeleted,
      backgroundColor: cs.primary.withOpacity(0.1),
      labelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
    ).animate().scale(duration: 200.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 6: The Habit
// ─────────────────────────────────────────────────────────────────────────────
class _Step6Habit extends ConsumerStatefulWidget {
  const _Step6Habit({required this.onComplete, required this.onBack, required this.isSaving});
  final VoidCallback onComplete;
  final VoidCallback onBack;
  final bool isSaving;

  @override
  ConsumerState<_Step6Habit> createState() => _Step6HabitState();
}

class _Step6HabitState extends ConsumerState<_Step6Habit> {
  late DateTime _selectedTime;

  @override
  void initState() {
    super.initState();
    final parts = ref.read(onboardingProvider).briefingTime.split(':');
    final now = DateTime.now();
    int h = 8, m = 0;
    if (parts.length == 2) {
      h = int.tryParse(parts[0]) ?? 8;
      m = int.tryParse(parts[1]) ?? 0;
    }
    _selectedTime = DateTime(now.year, now.month, now.day, h, m);
  }

  void _onTimeChanged(DateTime newTime) {
    setState(() => _selectedTime = newTime);
    final formatted = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
    ref.read(onboardingProvider.notifier).setBriefingTime(formatted);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'When do you want your daily update?',
            style: tt.headlineMedium,
          ).animate().fadeIn().slideX(begin: 0.1),
          const SizedBox(height: 48),
          
          Expanded(
            child: Center(
              child: SizedBox(
                height: 200,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: Theme.of(context).brightness,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: tt.displaySmall?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: _selectedTime,
                    onDateTimeChanged: _onTimeChanged,
                  ).animate().fadeIn(delay: 200.ms).scale(),
                ),
              ),
            ),
          ),
          
          Text(
            "We'll send you one quiet notification when your synthesis is ready. No breaking news alerts. No spam.",
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
          
          const SizedBox(height: 32),
          Row(
            children: [
              IconButton(
                onPressed: widget.isSaving ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
                padding: const EdgeInsets.all(16),
                style: IconButton.styleFrom(
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: widget.isSaving ? null : widget.onComplete,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: widget.isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Complete Setup'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Components
// ─────────────────────────────────────────────────────────────────────────────
class _FooterActions extends StatelessWidget {
  const _FooterActions({required this.onNext, required this.onBack});
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              padding: const EdgeInsets.all(16),
              style: IconButton.styleFrom(
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          if (onBack != null) const SizedBox(width: 16),
          Expanded(
            child: _NextButton(onPressed: onNext),
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
      ),
      child: const Text('Next'),
    );
  }
}
