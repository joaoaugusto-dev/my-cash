import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_cash/src/theme/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads saved theme mode from storage', () async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});

    final controller = await AppThemeController.create();

    expect(controller.themeMode, ThemeMode.dark);
  });

  test('persists theme mode when changed', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await AppThemeController.create();

    await controller.setThemeMode(ThemeMode.light);
    final preferences = await SharedPreferences.getInstance();

    expect(controller.themeMode, ThemeMode.light);
    expect(preferences.getString('app_theme_mode'), 'light');
  });
}
