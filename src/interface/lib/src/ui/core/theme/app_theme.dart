import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// Corner-radius scale. Bigger surfaces read as softer/closer to the user;
/// small controls stay tight so touch targets don't feel mushy.
class AppRadii {
  const AppRadii._();

  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 30;
  static const double xxl = 34;
  static const double pill = 999;
}

ColorScheme lightScheme() {
  return const ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.lightPrimary,
    onPrimary: Colors.white,
    primaryContainer: AppPalette.lightSoftPurple,
    onPrimaryContainer: AppPalette.lightPrimary,
    secondary: AppPalette.lightSecondary,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF3EEFF),
    onSecondaryContainer: Color(0xFF3B1372),
    tertiary: AppPalette.lightSuccess,
    onTertiary: Colors.white,
    tertiaryContainer: AppPalette.lightSuccessSoft,
    onTertiaryContainer: AppPalette.lightSuccessDark,
    error: AppPalette.lightError,
    onError: Colors.white,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: AppPalette.lightCard,
    onSurface: AppPalette.lightText,
    onSurfaceVariant: AppPalette.lightTextSecondary,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF9F7FE),
    surfaceContainer: Color(0xFFF3F0FC),
    surfaceContainerHigh: Color(0xFFEDE9FA),
    surfaceContainerHighest: Color(0xFFE6E1F7),
    outline: AppPalette.lightBorder,
    outlineVariant: Color(0xFFEDEBF3),
    inverseSurface: Color(0xFF241A3D),
    onInverseSurface: Color(0xFFF6F2FF),
    inversePrimary: AppPalette.darkPrimary,
    scrim: Colors.black,
    surfaceTint: AppPalette.lightPrimary,
  );
}

ColorScheme darkScheme() {
  return const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF7C3AED),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF3B1372),
    onPrimaryContainer: Color(0xFFE4D6FF),
    secondary: AppPalette.darkSecondary,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF3D2170),
    onSecondaryContainer: Color(0xFFEADCFF),
    tertiary: AppPalette.darkSuccess,
    onTertiary: Color(0xFF072312),
    tertiaryContainer: Color(0xFF16532E),
    onTertiaryContainer: AppPalette.darkSuccessSoft,
    error: AppPalette.darkError,
    onError: Color(0xFF1F0A0A),
    errorContainer: Color(0xFF5C1A1A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppPalette.darkCard,
    onSurface: AppPalette.darkText,
    onSurfaceVariant: AppPalette.darkTextSecondary,
    surfaceContainerLowest: Color(0xFF0A0716),
    surfaceContainerLow: Color(0xFF150E28),
    surfaceContainer: Color(0xFF1D1436),
    surfaceContainerHigh: Color(0xFF261B42),
    surfaceContainerHighest: Color(0xFF31234F),
    outline: AppPalette.darkBorder,
    outlineVariant: Color(0xFF2A2444),
    inverseSurface: Color(0xFFF6F2FF),
    onInverseSurface: Color(0xFF241A3D),
    inversePrimary: AppPalette.lightPrimary,
    scrim: Colors.black,
    surfaceTint: AppPalette.darkPrimary,
  );
}

/// App-wide type scale. One expressive family (Lato) instead of the
/// platform default, so the app doesn't read as generic Material
/// boilerplate. Money and other digit-heavy strings should opt into
/// [tabularFigures] so columns of amounts line up.
TextTheme appTextTheme(ColorScheme scheme) {
  final platformDefault = scheme.brightness == Brightness.dark
      ? Typography.material2021().white
      : Typography.material2021().black;
  final base = GoogleFonts.latoTextTheme(platformDefault)
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
      ._atLeast(FontWeight.w600);
  return base.copyWith(
        headlineSmall: base.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
        ),
      );
}

extension on TextTheme {
  /// Lato's default weight (400) reads thin next to the rest of the app —
  /// floors every style to at least [weight] without flattening styles
  /// that are already heavier (e.g. the w800 overrides above).
  TextTheme _atLeast(FontWeight weight) {
    TextStyle? bump(TextStyle? style) {
      if (style == null) return style;
      final current = style.fontWeight ?? FontWeight.w400;
      return current.value >= weight.value
          ? style
          : style.copyWith(fontWeight: weight);
    }

    return copyWith(
      displayLarge: bump(displayLarge),
      displayMedium: bump(displayMedium),
      displaySmall: bump(displaySmall),
      headlineLarge: bump(headlineLarge),
      headlineMedium: bump(headlineMedium),
      headlineSmall: bump(headlineSmall),
      titleLarge: bump(titleLarge),
      titleMedium: bump(titleMedium),
      titleSmall: bump(titleSmall),
      bodyLarge: bump(bodyLarge),
      bodyMedium: bump(bodyMedium),
      bodySmall: bump(bodySmall),
      labelLarge: bump(labelLarge),
      labelMedium: bump(labelMedium),
      labelSmall: bump(labelSmall),
    );
  }
}

const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];
