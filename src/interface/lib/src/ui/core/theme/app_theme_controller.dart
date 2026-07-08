import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._(this._preferences, this._themeMode);

  static const String _storageKey = 'app_theme_mode';

  final SharedPreferences _preferences;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  static Future<AppThemeController> create() async {
    final preferences = await SharedPreferences.getInstance();
    final storedMode = preferences.getString(_storageKey);
    return AppThemeController._(preferences, _decodeThemeMode(storedMode));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;
    await _preferences.setString(_storageKey, _encodeThemeMode(mode));
    notifyListeners();
  }

  static ThemeMode _decodeThemeMode(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _encodeThemeMode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
