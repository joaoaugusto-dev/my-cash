import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'theme/app_theme_controller.dart';

class AppPalette {
  const AppPalette._();

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF4C1D95);
  static const Color lightSecondary = Color(0xFF7C3AED);
  static const Color lightSoftPurple = Color(0xFFEDE9FE);
  static const Color lightSuccess = Color(0xFF22C55E);
  static const Color lightSuccessDark = Color(0xFF15803D);
  static const Color lightSuccessSoft = Color(0xFFDCFCE7);
  static const Color lightText = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightError = Color(0xFFEF4444);

  static const Color darkBackground = Color(0xFF0F0A1F);
  static const Color darkCard = Color(0xFF1A1033);
  static const Color darkPrimary = Color(0xFFA78BFA);
  static const Color darkSecondary = Color(0xFF8B5CF6);
  static const Color darkSoftPurple = Color(0xFF2E1A5C);
  static const Color darkSuccess = Color(0xFF4ADE80);
  static const Color darkSuccessDark = Color(0xFF22C55E);
  static const Color darkSuccessSoft = Color(0xFF123524);
  static const Color darkText = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkBorder = Color(0xFF3F3A5A);
  static const Color darkError = Color(0xFFF87171);
}

ColorScheme _lightScheme() {
  return const ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.lightPrimary,
    onPrimary: Colors.white,
    secondary: AppPalette.lightSecondary,
    onSecondary: Colors.white,
    error: AppPalette.lightError,
    onError: Colors.white,
    surface: AppPalette.lightCard,
    onSurface: AppPalette.lightText,
    tertiary: AppPalette.lightSuccess,
    onTertiary: Colors.white,
    outline: AppPalette.lightBorder,
  );
}

ColorScheme _darkScheme() {
  return const ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.darkPrimary,
    onPrimary: Color(0xFF1A1033),
    secondary: AppPalette.darkSecondary,
    onSecondary: Colors.white,
    error: AppPalette.darkError,
    onError: Color(0xFF1F0A0A),
    surface: AppPalette.darkCard,
    onSurface: AppPalette.darkText,
    tertiary: AppPalette.darkSuccess,
    onTertiary: Color(0xFF072312),
    outline: AppPalette.darkBorder,
  );
}

class App extends StatelessWidget {
  const App({super.key, required this.themeController});

  final AppThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final lightScheme = _lightScheme();
    final darkScheme = _darkScheme();

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MyCash',
        theme: ThemeData(
          colorScheme: lightScheme,
          scaffoldBackgroundColor: AppPalette.lightBackground,
          dividerColor: AppPalette.lightBorder,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppPalette.lightPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: AppPalette.lightCard.withValues(alpha: 0.82),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppPalette.lightBorder),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppPalette.lightCard.withValues(alpha: 0.74),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppPalette.lightBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppPalette.lightBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppPalette.lightSecondary),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppPalette.lightSecondary,
            foregroundColor: Colors.white,
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppPalette.lightPrimary,
            contentTextStyle: TextStyle(color: Colors.white),
          ),
          brightness: Brightness.light,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: darkScheme,
          scaffoldBackgroundColor: AppPalette.darkBackground,
          dividerColor: AppPalette.darkBorder,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppPalette.darkCard,
            foregroundColor: AppPalette.darkText,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: AppPalette.darkCard.withValues(alpha: 0.72),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppPalette.darkBorder),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppPalette.darkSoftPurple.withValues(alpha: 0.7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppPalette.darkBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppPalette.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppPalette.darkPrimary),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppPalette.darkSecondary,
            foregroundColor: Colors.white,
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppPalette.darkSoftPurple,
            contentTextStyle: TextStyle(color: AppPalette.darkText),
          ),
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        themeMode: themeController.themeMode,
        home: AuthGate(themeController: themeController),
      ),
    );
  }
}
