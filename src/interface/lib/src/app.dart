import 'package:flutter/material.dart';

import 'package:my_cash/src/ui/auth/widgets/auth_gate.dart';
import 'package:my_cash/src/ui/core/theme/app_theme.dart';
import 'package:my_cash/src/ui/core/theme/app_theme_controller.dart';

class App extends StatelessWidget {
  const App({super.key, required this.themeController, this.bootstrapError});

  final AppThemeController themeController;
  final String? bootstrapError;

  @override
  Widget build(BuildContext context) {
    final lightColorScheme = lightScheme();
    final darkColorScheme = darkScheme();

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MyCash',
        theme: ThemeData(
          colorScheme: lightColorScheme,
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
          colorScheme: darkColorScheme,
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
        home: bootstrapError == null
            ? AuthGate(themeController: themeController)
            : _BootstrapErrorPage(message: bootstrapError!),
      ),
    );
  }
}

class _BootstrapErrorPage extends StatelessWidget {
  const _BootstrapErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      'Configuração inválida do app',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
