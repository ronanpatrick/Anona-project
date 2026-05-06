import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showWidgetInstructions(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InfoSheet(
        icon: CupertinoIcons.square_grid_2x2,
        title: 'Android Widget Setup',
        content: '1. Long-press an empty space on your home screen.\n'
            '2. Tap Widgets.\n'
            '3. Find Anona.\n'
            '4. Drag the widget to your home screen.\n'
            '5. Resize if needed and tap it to open Anona.',
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This is a placeholder. Backend account deletion will be added in a later phase.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs       = Theme.of(context).colorScheme;
    final tt       = Theme.of(context).textTheme;
    final isDark   = settings.themeMode == ThemeMode.dark ||
        (settings.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: <Widget>[

          // ── Appearance ──────────────────────────────────────────────────
          _SectionHeader(label: 'Appearance'),
          const SizedBox(height: 8),

          // Dark Mode toggle (iOS-style)
          _SettingsTile(
            icon: CupertinoIcons.moon_stars_fill,
            iconColor: const Color(0xFF6C63FF),
            label: 'Dark Mode',
            trailing: CupertinoSwitch(
              value: isDark,
              activeColor: cs.primary,
              onChanged: (value) {
                settings.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),
          const SizedBox(height: 8),

          // System theme tile
          _SettingsTile(
            icon: CupertinoIcons.device_phone_portrait,
            iconColor: const Color(0xFF4A90D9),
            label: 'Follow System Theme',
            trailing: CupertinoSwitch(
              value: settings.themeMode == ThemeMode.system,
              activeColor: cs.primary,
              onChanged: (value) {
                settings.setThemeMode(
                    value ? ThemeMode.system : ThemeMode.light);
              },
            ),
          ),
          const SizedBox(height: 20),

          // Font size
          _SectionHeader(label: 'Reading'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: CupertinoIcons.textformat_size,
            iconColor: const Color(0xFF34C759),
            label: 'Font Size',
            subtitle: '${(settings.fontSizeFactor * 100).round()}%',
            trailing: const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
              child: Slider(
                value: settings.fontSizeFactor,
                min: 0.85,
                max: 1.35,
                divisions: 10,
                label: '${(settings.fontSizeFactor * 100).round()}%',
                onChanged: settings.setFontSizeFactor,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Audio
          _SectionHeader(label: 'Audio'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: CupertinoIcons.waveform,
            iconColor: const Color(0xFFFF9F0A),
            label: 'Playback Speed',
            subtitle: '${settings.audioSpeed.toStringAsFixed(2)}×',
            trailing: const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
              child: Slider(
                value: settings.audioSpeed,
                min: 0.6,
                max: 1.4,
                divisions: 8,
                label: '${settings.audioSpeed.toStringAsFixed(2)}×',
                onChanged: settings.setAudioSpeed,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Widget
          _SectionHeader(label: 'Widget'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: CupertinoIcons.square_grid_2x2,
            iconColor: const Color(0xFF30D158),
            label: 'Home Screen Widget',
            subtitle: 'How to add the widget',
            trailing: const Icon(CupertinoIcons.chevron_right, size: 14),
            onTap: () => _showWidgetInstructions(context),
          ),
          const SizedBox(height: 20),

          // Danger zone
          _SectionHeader(label: 'Account', danger: true),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: CupertinoIcons.delete,
            iconColor: cs.error,
            label: 'Delete Account',
            labelColor: cs.error,
            trailing: const Icon(CupertinoIcons.chevron_right, size: 14),
            onTap: () => _confirmDeleteAccount(context),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.danger = false});
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: danger ? cs.error : cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.trailing,
    this.subtitle,
    this.labelColor,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AnonaColors.surfaceDark2 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AnonaColors.surfaceDark2 : const Color(0xFFE8E8E3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        title: Text(
          label,
          style: tt.titleSmall?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle!, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant))
            : null,
        trailing: trailing,
        onTap: onTap,
        horizontalTitleGap: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.icon,
    required this.title,
    required this.content,
  });
  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: isDark
              ? AnonaColors.surfaceDark.withOpacity(0.96)
              : Colors.white.withOpacity(0.97),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(icon, color: cs.primary),
                  const SizedBox(width: 10),
                  Text(title, style: tt.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              Text(content, style: tt.bodyLarge),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
