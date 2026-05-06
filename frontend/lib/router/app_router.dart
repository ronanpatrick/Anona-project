import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: <RouteBase>[
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

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title Screen'),
      ),
    );
  }
}

