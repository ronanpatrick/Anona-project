import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'briefing_screen.dart';
import 'home_screen.dart';
import 'saved_screen.dart';
import '../widgets/main_drawer.dart';
import '../theme/app_theme.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  static const _destinations = <_NavDestination>[
    _NavDestination(
      icon:       CupertinoIcons.house,
      activeIcon: CupertinoIcons.house_fill,
      label:      'Today',
    ),
    _NavDestination(
      icon:       CupertinoIcons.mic,
      activeIcon: CupertinoIcons.mic_fill,
      label:      'Briefing',
    ),
    _NavDestination(
      icon:       CupertinoIcons.bookmark,
      activeIcon: CupertinoIcons.bookmark_fill,
      label:      'Saved',
    ),
  ];

  final List<Widget> _tabs = const <Widget>[
    HomeScreen(),
    BriefingScreen(),
    SavedScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // ── Top AppBar ──────────────────────────────────────────────────────
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            // Wordmark
            Text(
              'anona',
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'DAILY',
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),

      endDrawer: const MainDrawer(),

      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),

      // ── Frosted-glass Bottom Navigation ─────────────────────────────────
      extendBody: true,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AnonaColors.surfaceDark.withOpacity(0.88)
                  : Colors.white.withOpacity(0.88),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_destinations.length, (i) {
                    final dest    = _destinations[i];
                    final active  = i == _currentIndex;
                    return _NavItem(
                      destination: dest,
                      isActive: active,
                      primaryColor: cs.primary,
                      inactiveColor: cs.onSurface.withOpacity(0.4),
                      textTheme: tt,
                      onTap: () => setState(() => _currentIndex = i),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Internal models & widgets ────────────────────────────────────────────────

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isActive,
    required this.primaryColor,
    required this.inactiveColor,
    required this.textTheme,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool isActive;
  final Color primaryColor;
  final Color inactiveColor;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? destination.activeIcon : destination.icon,
                key: ValueKey(isActive),
                size: 22,
                color: isActive ? primaryColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: textTheme.labelSmall!.copyWith(
                color: isActive ? primaryColor : inactiveColor,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(destination.label),
            ),
          ],
        ),
      ),
    );
  }
}
