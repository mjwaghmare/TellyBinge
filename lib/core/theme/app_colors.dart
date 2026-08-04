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
}
