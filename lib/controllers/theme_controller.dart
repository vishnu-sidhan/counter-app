import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages application theme mode (Light / Dark) with local persistence.
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  static const String _prefKey = 'app_theme_mode';
  ThemeMode _themeMode = ThemeMode.light; // Default to Light theme

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> init([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final saved = p.getString(_prefKey);
    if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (saved == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light; // Default to Light
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _prefKey,
        mode == ThemeMode.dark
            ? 'dark'
            : (mode == ThemeMode.system ? 'system' : 'light'),
      );
    } catch (_) {
      // Gracefully handle persistence in test environments
    }
  }
}
