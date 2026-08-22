import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static String? get fontFamily => GoogleFonts.plusJakartaSans().fontFamily;

  static TextStyle get xs => GoogleFonts.plusJakartaSans(
        fontSize: 12.0,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      );

  static TextStyle get xsMedium => GoogleFonts.plusJakartaSans(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get sm => GoogleFonts.plusJakartaSans(
        fontSize: 14.0,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      );

  static TextStyle get smMedium => GoogleFonts.plusJakartaSans(
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get smBold => GoogleFonts.plusJakartaSans(
        fontSize: 14.0,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  static TextStyle get md => GoogleFonts.plusJakartaSans(
        fontSize: 16.0,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      );

  static TextStyle get mdMedium => GoogleFonts.plusJakartaSans(
        fontSize: 16.0,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get mdBold => GoogleFonts.plusJakartaSans(
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  static TextStyle get lg => GoogleFonts.plusJakartaSans(
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get xl => GoogleFonts.plusJakartaSans(
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  static TextStyle get xsBold => GoogleFonts.plusJakartaSans(
        fontSize: 12.0,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  static TextStyle get xxl => GoogleFonts.plusJakartaSans(
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );
}

extension TextStyleColorX on TextStyle {
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withTabularFigures() => copyWith(
        fontFeatures: [
          ...?fontFeatures,
          const FontFeature.tabularFigures(),
        ],
      );
}

