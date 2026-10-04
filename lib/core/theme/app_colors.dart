import 'package:flutter/material.dart';

/// Application color tokens and Material 3 ColorSchemes.
abstract final class AppColors {
  // Primary Nordic Pine & Warm Amber accents
  static const Color primarySeed = Color(0xFF1F6E58);
  static const Color secondarySeed = Color(0xFFD97736);
  static const Color tertiarySeed = Color(0xFF4A6FA5);

  // Neutral Surfaces (Light)
  static const Color lightBackground = Color(0xFFF8FAF9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFF0F4F2);

  // Neutral Surfaces (Dark)
  static const Color darkBackground = Color(0xFF0E1513);
  static const Color darkSurface = Color(0xFF151F1C);
  static const Color darkSurfaceContainer = Color(0xFF1D2A26);

  // Semantic Status Colors
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);

  /// Light Material 3 [ColorScheme].
  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: primarySeed,
    secondary: secondarySeed,
    tertiary: tertiarySeed,
    brightness: Brightness.light,
    surface: lightSurface,
    surfaceContainerLow: lightBackground,
    surfaceContainer: lightSurfaceContainer,
    error: error,
  );

  /// Dark Material 3 [ColorScheme].
  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: primarySeed,
    secondary: secondarySeed,
    tertiary: tertiarySeed,
    brightness: Brightness.dark,
    surface: darkSurface,
    surfaceContainerLow: darkBackground,
    surfaceContainer: darkSurfaceContainer,
  );
}
