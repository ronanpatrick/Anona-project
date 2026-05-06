import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';

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
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // User info
    final user     = Supabase.instance.client.auth.currentUser;
    final email    = (user?.email ?? '').trim();
    final md       = user?.userMetadata;
    final fullName = md is Map<String, dynamic>
        ? ((md['full_name'] ?? md['name'] ?? '') as String).trim()
        : '';
    final initials = fullName.isNotEmpty
        ? fullName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
        : (email.isNotEmpty ? email[0].toUpperCase() : 'A');

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight:    Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Drawer(
          backgroundColor: isDark
              ? AnonaColors.surfaceDark.withOpacity(0.95)
              : Colors.white.withOpacity(0.97),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── User header card ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    children: [
                      // Avatar circle
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [cs.primary, cs.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: tt.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (fullName.isNotEmpty)
                              Text(
                                fullName,
                                style: tt.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              email.isNotEmpty ? email : 'Anona User',
                              style: tt.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: cs.outline.withOpacity(0.4)),
                ),
                const SizedBox(height: 8),

                // ── Nav items ────────────────────────────────────────────
                _DrawerItem(
                  icon: CupertinoIcons.person_circle,
                  label: 'Profile',
                  onTap: () => _navigateTo(context, const ProfileScreen()),
                ),
                _DrawerItem(
                  icon: CupertinoIcons.slider_horizontal_3,
                  label: 'Settings',
                  onTap: () => _navigateTo(context, const SettingsScreen()),
                ),

                const Spacer(),

                // ── Sign out ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: cs.outline.withOpacity(0.4)),
                ),
                _DrawerItem(
                  icon: CupertinoIcons.square_arrow_right,
                  label: 'Sign Out',
                  iconColor: cs.error,
                  labelColor: cs.error,
                  onTap: () => _signOut(context),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (iconColor ?? cs.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor ?? cs.primary),
        ),
        title: Text(
          label,
          style: tt.titleSmall?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          CupertinoIcons.chevron_right,
          size: 14,
          color: (labelColor ?? cs.onSurfaceVariant).withOpacity(0.5),
        ),
        onTap: onTap,
        horizontalTitleGap: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
