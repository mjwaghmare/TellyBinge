import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Colors
  static const Color primary = Color(0xFFFFC107); // Amber Yellow
  static const Color primaryDark = Color(0xFFFF8F00); // Darker Amber for presses/accents
  static const Color primaryLight = Color(0xFFFFD54F); // Lighter Amber

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0D0D0D); // Solid dark background
  static const Color background = Color(0xFF0D0D0D); // Solid dark background
  static const Color surface = Color(0xFF161616); // Card background
  static const Color surfaceLight = Color(0xFF222222); // Input fields, list tiles
  
  // Status Colors
  static const Color watched = Color(0xFFFFC107); // Yellow/Amber watch progress
  static const Color airing = Color(0xFF2196F3); // Blue for shows that are airing
  static const Color ended = Color(0xFF9C27B0); // Purple for ended shows
  static const Color error = Color(0xFFE53935); // Red for error states
  static const Color success = Color(0xFF4CAF50); // Green for positive states

  // Accent & Surface Tokens
  static const Color brandGreen = Color(0xFF6B8E23); // Green badge accent
  static const Color accentBlue = Color(0xFF1E88E5); // Blue action accent
  static const Color surfaceDarkAlt = Color(0xFF1E1E1E); // Sheet / Card background
  static const Color surfaceElevated = Color(0xFF2C2C2E); // Elevated tile / input fill
  static const Color borderLight = Color(0xFFCCCCCC); // Light divider / border

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF757575);
  static const Color textOnPrimary = Color(0xFF000000);

  // Heatmap Activity Tokens
  static const Color heatmapEmptyLight = Color(0xFFEBEDF0);
  static const Color heatmapEmptyDark = Color(0xFF161B22);
  static const List<Color> heatmapGreenScale = [
    Color(0xFF0E4429),
    Color(0xFF006D32),
    Color(0xFF26A641),
    Color(0xFF39D353),
  ];
  static const List<Color> heatmapYellowScale = [
    Color(0xFF3E2D00),
    Color(0xFF7C5A00),
    Color(0xFFB98700),
    primary,
  ];

  // Dynamic Theme Helpers
  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color chipBorder(BuildContext context) =>
      isLight(context) ? Colors.grey.shade300 : borderLight;

  static Color heatmapEmpty(BuildContext context) =>
      isLight(context) ? heatmapEmptyLight : heatmapEmptyDark;
}

extension BuildContextColorX on BuildContext {
  bool get isLight => Theme.of(this).brightness == Brightness.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color adaptiveColor({required Color light, required Color dark}) =>
      isLight ? light : dark;
}
