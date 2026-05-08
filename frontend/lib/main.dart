import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/settings_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/main_scaffold.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('DEBUG: Starting Anona initialization...');

  try {
    await dotenv.load(fileName: '.env');
    debugPrint('DEBUG: Dotenv loaded.');
  } catch (e) {
    debugPrint('DEBUG: Dotenv load failed (falling back to platform env): $e');
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  debugPrint('DEBUG: Supabase initialized.');

  final notificationService = NotificationService();
  await notificationService.init();
  debugPrint('DEBUG: Notification service init completed.');

  runApp(
    ProviderScope(
      child: ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
        child: const AnonaApp(),
      ),
    ),
  );
  
  // Request permissions in the background after startup
  notificationService.requestPermissions();
}

class AnonaApp extends StatelessWidget {
  const AnonaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppRoot();
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final client = Supabase.instance.client;
    return MaterialApp(
      title: 'Anona',
      theme: AppTheme.getLightTheme(fontSizeFactor: settings.fontSizeFactor),
      darkTheme: AppTheme.getDarkTheme(fontSizeFactor: settings.fontSizeFactor),
      themeMode: settings.themeMode,
      home: StreamBuilder<AuthState>(
        stream: client.auth.onAuthStateChange,
        initialData: AuthState(AuthChangeEvent.initialSession, client.auth.currentSession),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final session = snapshot.data?.session;
          if (session != null) {
            return _OnboardingGate(userId: session.user.id);
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate({required this.userId});

  final String userId;

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  late Future<bool> _onboardingStatusFuture;

  @override
  void initState() {
    super.initState();
    _onboardingStatusFuture = _checkOnboardingStatus();
  }

  @override
  void didUpdateWidget(covariant _OnboardingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _onboardingStatusFuture = _checkOnboardingStatus();
    }
  }

  Future<bool> _checkOnboardingStatus() async {
    try {
      final response = await Supabase.instance.client
          .from('user_preferences')
          .select('selected_topics')
          .eq('id', widget.userId)
          .maybeSingle();

      if (response == null) return false;
      
      final topics = response['selected_topics'] as List?;
      // If topics is null or empty, they need onboarding
      return topics != null && topics.isNotEmpty;
    } catch (e) {
      debugPrint('DEBUG: Error checking onboarding status: $e');
      return false;
    }
  }

  void _refreshAfterOnboarding() {
    setState(() {
      _onboardingStatusFuture = _checkOnboardingStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _onboardingStatusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          // Fallback to onboarding if there's an error checking status
          return OnboardingScreen(onCompleted: _refreshAfterOnboarding);
        }

        final hasCompletedOnboarding = snapshot.data ?? false;
        if (hasCompletedOnboarding) {
          return const MainScaffold();
        }
        
        return OnboardingScreen(onCompleted: _refreshAfterOnboarding);
      },
    );
  }
}

