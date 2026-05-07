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

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  await NotificationService().init();

  runApp(
    ProviderScope(
      child: ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
        child: const AnonaApp(),
      ),
    ),
  );
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
  late Future<bool> _hasPreferencesFuture;

  @override
  void initState() {
    super.initState();
    _hasPreferencesFuture = _hasUserPreferences();
  }

  @override
  void didUpdateWidget(covariant _OnboardingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _hasPreferencesFuture = _hasUserPreferences();
    }
  }

  Future<bool> _hasUserPreferences() async {
    final row = await Supabase.instance.client
        .from('user_preferences')
        .select('id')
        .eq('id', widget.userId)
        .maybeSingle();
    return row != null;
  }

  void _refreshAfterOnboarding() {
    setState(() {
      _hasPreferencesFuture = _hasUserPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasPreferencesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const AuthScreen();
        }
        if (snapshot.data == true) {
          return const MainScaffold();
        }
        return OnboardingScreen(onCompleted: _refreshAfterOnboarding);
      },
    );
  }
}

