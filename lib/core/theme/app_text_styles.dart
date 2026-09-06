import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static String? get fontFamily => GoogleFonts.plusJakartaSans().fontFamily;

  static TextStyle get xs => GoogleFonts.plusJakartaSans(
    fontSize: 12.0,
    fontWeight: FontWeight.normal,
  );

  static TextStyle get xsMedium =>
      GoogleFonts.plusJakartaSans(fontSize: 12.0, fontWeight: FontWeight.w500);

  static TextStyle get sm => GoogleFonts.plusJakartaSans(
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
  );

  static TextStyle get smMedium =>
      GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.w500);

  static TextStyle get smBold =>
      GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold);

  static TextStyle get md => GoogleFonts.plusJakartaSans(
    fontSize: 16.0,
    fontWeight: FontWeight.normal,
  );

  static TextStyle get mdMedium =>
      GoogleFonts.plusJakartaSans(fontSize: 16.0, fontWeight: FontWeight.w500);

  static TextStyle get mdBold =>
      GoogleFonts.plusJakartaSans(fontSize: 16.0, fontWeight: FontWeight.bold);

  static TextStyle get lg =>
      GoogleFonts.plusJakartaSans(fontSize: 20.0, fontWeight: FontWeight.w600);

  static TextStyle get xl =>
      GoogleFonts.plusJakartaSans(fontSize: 24.0, fontWeight: FontWeight.bold);

  static TextStyle get xsBold =>
      GoogleFonts.plusJakartaSans(fontSize: 12.0, fontWeight: FontWeight.bold);

  static TextStyle get xxl =>
      GoogleFonts.plusJakartaSans(fontSize: 32.0, fontWeight: FontWeight.bold);

  /// Onboarding / login hero headline. Tighter leading and negative tracking
  /// than the scale below it, so a multi-line headline reads as one block.
  static TextStyle get display => GoogleFonts.plusJakartaSans(
    fontSize: 38.0,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  // ---------------------------------------------------------------------------
  // Display Accent 1: Bebas Neue (Cinematic, Poster, Bold Condensed)
  // ---------------------------------------------------------------------------

  /// Hero title style for large cinematic headlines.
  static TextStyle get posterTitle => GoogleFonts.bebasNeue(
    fontSize: 32.0,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
  );

  /// Section headers for movie & show pages (e.g., 'MOVIE INFO', 'CAST & CREW').
  static TextStyle get posterHeader => GoogleFonts.bebasNeue(
    fontSize: 22.0,
    letterSpacing: 1.0,
    color: AppColors.textPrimary,
  );

  /// Display numbers for countdown timers, watch hours, and profile metrics.
  static TextStyle get posterStat => GoogleFonts.bebasNeue(
    fontSize: 22.0,
    letterSpacing: 0.8,
  );

  // ---------------------------------------------------------------------------
  // Display Accent 2: Playfair Display (Prestige, Editorial, Award-Winning Serif)
  // ---------------------------------------------------------------------------

  /// Movie/Show taglines and critic quotes.
  static TextStyle get editorialTagline => GoogleFonts.playfairDisplay(
    fontSize: 15.0,
    fontStyle: FontStyle.italic,
    height: 1.35,
    letterSpacing: 0.2,
  );

  /// Editorial quotes or spotlight titles.
  static TextStyle get editorialQuote => GoogleFonts.playfairDisplay(
    fontSize: 17.0,
    fontStyle: FontStyle.italic,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// Elegant serif titles for prestige features or awards.
  static TextStyle get editorialTitle => GoogleFonts.playfairDisplay(
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textPrimary,
  );
}

extension TextStyleColorX on TextStyle {
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withTabularFigures() => copyWith(
    fontFeatures: [...?fontFeatures, const FontFeature.tabularFigures()],
  );
}
