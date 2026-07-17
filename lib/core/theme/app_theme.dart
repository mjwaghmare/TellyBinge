import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData darkTheme(bool isOled) {
    final scaffoldBg = isOled ? Colors.black : AppColors.background;
    final cardBg = isOled ? const Color(0xFF121212) : Colors.black;
    final dividerBg = isOled ? const Color(0xFF1C1C1E) : AppColors.surfaceLight;
    final appBarBg = isOled ? Colors.black : AppColors.background;
    final bottomNavBg = isOled ? Colors.black : AppColors.surface;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      dividerColor: dividerBg,
      textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: cardBg,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: const TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bottomNavBg,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        selectedLabelStyle: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 12.0),
        type: BottomNavigationBarType.fixed,
        elevation: 8.0,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 2.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}
