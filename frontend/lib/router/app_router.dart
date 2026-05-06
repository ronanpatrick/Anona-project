import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth_screen.dart';
import '../screens/onboarding_screen.dart';
import '../services/auth_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const _AuthGateScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (BuildContext context, GoRouterState state) =>
            const AuthScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (BuildContext context, GoRouterState state) =>
            const _PlaceholderScreen(title: 'Home'),
      ),
      GoRoute(
        path: '/briefing',
        builder: (BuildContext context, GoRouterState state) =>
            const _PlaceholderScreen(title: 'Briefing'),
      ),
      GoRoute(
        path: '/saved',
        builder: (BuildContext context, GoRouterState state) =>
            const _PlaceholderScreen(title: 'Saved'),
      ),
    ],
  );
});

class _AuthGateScreen extends ConsumerWidget {
  const _AuthGateScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const _LoaderScaffold(),
      error: (_, __) => const _ErrorScaffold(
        message: 'Unable to check authentication state.',
      ),
      data: (_) {
        final user = ref.read(authServiceProvider).currentUser;
        if (user == null) {
          return const AuthScreen();
        }

        final onboardingState =
            ref.watch(hasCompletedOnboardingProvider(user.id));
        return onboardingState.when(
          loading: () => const _LoaderScaffold(),
          error: (_, __) => const _ErrorScaffold(
            message: 'Unable to load onboarding status.',
          ),
          data: (hasCompletedOnboarding) {
            if (!hasCompletedOnboarding) {
              return const OnboardingScreen();
            }
            return const _PlaceholderScreen(title: 'Home');
          },
        );
      },
    );
  }
}

class _LoaderScaffold extends StatelessWidget {
  const _LoaderScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(message)),
    );
  }
}

class _PlaceholderScreen extends ConsumerWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                context.go('/auth');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Text('$title Screen'),
      ),
    );
  }
}

