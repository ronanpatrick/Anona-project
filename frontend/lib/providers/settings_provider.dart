import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _themeModeKey = 'settings.themeMode';
  static const String _fontSizeFactorKey = 'settings.fontSizeFactor';
  static const String _audioSpeedKey = 'settings.audioSpeed';

  ThemeMode _themeMode = ThemeMode.system;
  double _fontSizeFactor = 1.0;
  double _audioSpeed = 1.0;

  SettingsProvider() {
    _loadSettings();
  }

  ThemeMode get themeMode => _themeMode;
  double get fontSizeFactor => _fontSizeFactor;
  double get audioSpeed => _audioSpeed;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeModeKey);
    final savedFontFactor = prefs.getDouble(_fontSizeFactorKey);
    final savedAudioSpeed = prefs.getDouble(_audioSpeedKey);

    _themeMode = _themeModeFromString(savedTheme);
    _fontSizeFactor = _clampFontSize(savedFontFactor ?? 1.0);
    _audioSpeed = _clampAudioSpeed(savedAudioSpeed ?? 1.0);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeModeToString(mode));
  }

  Future<void> setFontSizeFactor(double value) async {
    _fontSizeFactor = _clampFontSize(value);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeFactorKey, _fontSizeFactor);
  }

  Future<void> setAudioSpeed(double value) async {
    _audioSpeed = _clampAudioSpeed(value);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_audioSpeedKey, _audioSpeed);
  }

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  double _clampFontSize(double value) {
    return value.clamp(0.85, 1.35).toDouble();
  }

  double _clampAudioSpeed(double value) {
    return value.clamp(0.6, 1.4).toDouble();
  }
}
