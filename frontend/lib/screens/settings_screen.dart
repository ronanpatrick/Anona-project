import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> _showWidgetInstructions(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Android Widget Setup'),
          content: const Text(
            '1. Long-press an empty space on your home screen.\n'
            '2. Tap Widgets.\n'
            '3. Find Anona.\n'
            '4. Drag the widget to your home screen.\n'
            '5. Resize if needed and tap it to open Anona.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This is a placeholder for now. Backend account deletion will be added in a later phase.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          DropdownButtonFormField<ThemeMode>(
            value: settings.themeMode,
            decoration: const InputDecoration(
              labelText: 'Theme',
              border: OutlineInputBorder(),
            ),
            items: ThemeMode.values
                .map(
                  (mode) => DropdownMenuItem<ThemeMode>(
                    value: mode,
                    child: Text(_themeModeLabel(mode)),
                  ),
                )
                .toList(growable: false),
            onChanged: (mode) {
              if (mode != null) {
                settings.setThemeMode(mode);
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Font Size (${settings.fontSizeFactor.toStringAsFixed(2)}x)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: settings.fontSizeFactor,
            min: 0.85,
            max: 1.35,
            divisions: 10,
            label: settings.fontSizeFactor.toStringAsFixed(2),
            onChanged: (value) {
              settings.setFontSizeFactor(value);
            },
          ),
          const SizedBox(height: 20),
          Text('Audio Preferences', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'AI Voice Playback Speed (${settings.audioSpeed.toStringAsFixed(2)}x)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: settings.audioSpeed,
            min: 0.6,
            max: 1.4,
            divisions: 8,
            label: settings.audioSpeed.toStringAsFixed(2),
            onChanged: (value) {
              settings.setAudioSpeed(value);
            },
          ),
          const SizedBox(height: 20),
          Text('Widget Instructions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('How to add Android home screen widget'),
            onTap: () => _showWidgetInstructions(context),
          ),
          const SizedBox(height: 20),
          Text('System', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => _confirmDeleteAccount(context),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }
}
