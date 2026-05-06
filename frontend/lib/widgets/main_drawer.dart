import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  Future<void> _navigateTo(BuildContext context, Widget screen) async {
    Navigator.of(context).pop();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            const ListTile(
              title: Text(
                'Menu',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => _navigateTo(context, const ProfileScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => _navigateTo(context, const SettingsScreen()),
            ),
            const Spacer(),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Log Out',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }
}
