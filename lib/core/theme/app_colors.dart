import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 1. Primary Brand Accent Tokens
  static const Color primary = Color(0xFF8B5CF6); // Electric Violet (Dark Mode)
  static const Color primaryDark = Color(0xFF6D28D9); // Dark Violet accent
  static const Color primaryLight = Color(0xFFA78BFA); // Light Violet accent
  static const Color lightPrimary = Color(0xFF7C3AED); // Vivid Deep Violet (Light Mode, WCAG AA 5.8:1)
  static const Color lightPrimaryContainer = Color(0xFFF3E8FF); // Soft pastel violet container
  static const Color lightOnPrimaryContainer = Color(0xFF6D28D9); // Deep violet on pastel container

  // 2. 3-Tier Surface Hierarchy (Dark Mode)
  static const Color darkBackground = Color(0xFF0D0D0D); // Level 0: Canvas
  static const Color background = darkBackground;
  static const Color surface = Color(0xFF161616); // Level 1: Cards / Tiles
  static const Color surfaceElevated = Color(
    0xFF242424,
  ); // Level 2: Modals / Sheets
  static const Color surfaceLight = surfaceElevated; // Compatibility alias
  static const Color surfaceDarkAlt = surfaceElevated; // Compatibility alias

  // 3-Tier Surface Hierarchy (Light Mode)
  static const Color lightBackground = Color(0xFFF9F9FB); // Level 0: Canvas
  static const Color lightSurface = Color(0xFFFFFFFF); // Level 1: Cards
  static const Color lightSurfaceElevated = Color(
    0xFFF3F4F6,
  ); // Level 2: Modals

  // Ambient Card Shadow (Light Mode)
  static const List<BoxShadow> lightCardShadow = [
    BoxShadow(
      color: Color(0x0A000000), // 4% black
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  // 3. Status & Functional Tokens
  static const Color watched = primary; // Violet watch indicator
  static const Color airing = Color(0xFF2196F3); // Blue for airing shows
  static const Color ended = Color(0xFF757575); // Neutral Grey for ended shows
  static const Color error = Color(0xFFE53935); // Red for error/destructive
  static const Color success = Color(0xFF4CAF50); // Green for positive states

  // Light Mode Status Tonal Containers
  static const Color lightSuccessContainer = Color(0xFFDCFCE7);
  static const Color lightOnSuccessContainer = Color(0xFF15803D);
  static const Color lightAiringContainer = Color(0xFFDBEAFE);
  static const Color lightOnAiringContainer = Color(0xFF1D4ED8);
  static const Color lightErrorContainer = Color(0xFFFEE2E2);
  static const Color lightOnErrorContainer = Color(0xFFB91C1C);
  static const Color lightEndedContainer = Color(0xFFF3F4F6);
  static const Color lightOnEndedContainer = Color(0xFF4B5563);

  // 4. Accent & Divider Tokens
  static const Color brandGreen = Color(0xFF6B8E23); // Green badge accent
  static const Color accentBlue = Color(0xFF1E88E5); // Blue action accent
  static const Color skyBlue = Color(0xFF64B5F6); // Sky blue accent
  static const Color borderLight = Color(0xFFE5E7EB); // Light divider / border
  static const Color borderDark = Color(0xFF2C2C2E); // Dark divider / border
  static const Color errorSoft = Color(0xFFFF6B6B); // Soft error/red

  // 4b. Achievement Tier Tokens
  static const Color bronze = Color(0xFFCD7F32);
  static const Color bronzeDark = Color(0xFFA0522D);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color silverDark = Color(0xFF808080);
  static const Color gold = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFFDAA520);
  static const Color diamond = Color(0xFFB9F2FF);
  static const Color diamondDark = Color(0xFF4FC3F7);

  // 4c. Partner & Service Tokens
  static const Color tmdbDarkBlue = Color(0xFF032541);
  static const Color tmdbLightBlue = Color(0xFF01B4E4);

  // 4d. Stacked Surface Tokens
  static const Color surfaceStackedDark = Color(0xFF2E2E2E);
  static const Color surfaceStackedDarkElevated = Color(0xFF383838);

  // 5. Text Tokens (Dark Mode)
  static const Color textPrimary = Color(0xFFF4F4F5); // 92% off-white (anti-halation, reduced eye fatigue)
  static const Color textSecondary = Color(0xFFA1A1AA); // Balanced zinc secondary
  static const Color textTertiary = Color(0xFF71717A); // Balanced zinc tertiary
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Text Tokens (Light Mode)
  static const Color lightTextPrimary = Color(0xFF1F2937);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextTertiary = Color(0xFF64748B);

  // 6. Heatmap Activity Tokens
  static const Color heatmapEmptyLight = Color(0xFFEBEDF0);
  static const Color heatmapEmptyDark = Color(0xFF161B22);

  // Green scale: Light mode (soft pastel to rich deep forest green)
  static const List<Color> heatmapGreenScaleLight = [
    Color(0xFF9BE9A8), // Level 1: Soft pastel green
    Color(0xFF40C463), // Level 2: Fresh vibrant green
    Color(0xFF219653), // Level 3: Rich medium green
    Color(0xFF14532D), // Level 4: Deep forest green
  ];

  // Green scale: Dark mode (deep muted to bright glowing green)
  static const List<Color> heatmapGreenScaleDark = [
    Color(0xFF0E4429), // Level 1: Deep muted green
    Color(0xFF006D32), // Level 2: Dark green
    Color(0xFF26A641), // Level 3: Medium green
    Color(0xFF39D353), // Level 4: Glowing neon green
  ];

  // Violet scale: Light mode (soft lavender to rich deep purple)
  static const List<Color> heatmapVioletScaleLight = [
    Color(0xFFDDD6FE), // Level 1: Soft lavender
    Color(0xFFA78BFA), // Level 2: Medium violet
    Color(0xFF7C3AED), // Level 3: Vivid purple
    Color(0xFF4C1D95), // Level 4: Deep royal purple
  ];

  // Violet scale: Dark mode (deep muted to bright glowing violet)
  static const List<Color> heatmapVioletScaleDark = [
    Color(0xFF2E1065), // Level 1: Deep muted violet
    Color(0xFF5B21B6), // Level 2: Deep purple
    Color(0xFF7C3AED), // Level 3: Vivid purple
    Color(0xFFA78BFA), // Level 4: Glowing light violet
  ];

  // Compatibility aliases
  static const List<Color> heatmapGreenScale = heatmapGreenScaleDark;
  static const List<Color> heatmapVioletScale = heatmapVioletScaleDark;
  static const List<Color> heatmapYellowScale = heatmapVioletScaleDark;

  // Dynamic Theme Helpers
  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color primaryColor(BuildContext context) =>
      isLight(context) ? lightPrimary : primary;

  static Color primaryContainerColor(BuildContext context) =>
      isLight(context)
          ? lightPrimaryContainer
          : primary.withValues(alpha: 0.15);

  static Color chipBorder(BuildContext context) =>
      isLight(context) ? borderLight : borderDark;

  static Color heatmapEmpty(BuildContext context) =>
      isLight(context) ? heatmapEmptyLight : heatmapEmptyDark;

  static List<Color> heatmapGreen(BuildContext context) =>
      isLight(context) ? heatmapGreenScaleLight : heatmapGreenScaleDark;

  static List<Color> heatmapViolet(BuildContext context) =>
      isLight(context) ? heatmapVioletScaleLight : heatmapVioletScaleDark;

  static Color textPrimaryColor(BuildContext context) =>
      isLight(context) ? lightTextPrimary : textPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      isLight(context) ? lightTextSecondary : textSecondary;

  static Color textTertiaryColor(BuildContext context) =>
      isLight(context) ? lightTextTertiary : textTertiary;
}

extension BuildContextColorX on BuildContext {
  bool get isLight => Theme.of(this).brightness == Brightness.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color adaptiveColor({required Color light, required Color dark}) =>
      isLight ? light : dark;

  Color get primary =>
      isLight ? AppColors.lightPrimary : AppColors.primary;
  Color get primaryContainer =>
      isLight
          ? AppColors.lightPrimaryContainer
          : AppColors.primary.withValues(alpha: 0.15);
  Color get onPrimaryContainer =>
      isLight ? AppColors.lightOnPrimaryContainer : AppColors.primaryLight;

  Color get textPrimary =>
      isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
  Color get textSecondary =>
      isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
  Color get textTertiary =>
      isLight ? AppColors.lightTextTertiary : AppColors.textTertiary;
}
