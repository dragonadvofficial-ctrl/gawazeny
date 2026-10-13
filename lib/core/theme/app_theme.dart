import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'text_styles.dart';

/// Design system theme definition for "جوزيني يا ماما".
abstract final class AppTheme {
  /// Primary Light Theme configured for Arabic RTL by default.
  static ThemeData get lightTheme {
    final baseTextTheme = AppTextStyles.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryNavy,
      scaffoldBackgroundColor: AppColors.offWhite,
      fontFamily: GoogleFonts.cairo().fontFamily,

      // Color Scheme
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primaryNavy,
        onPrimary: AppColors.surfaceWhite,
        secondary: AppColors.secondaryPink,
        onSecondary: AppColors.surfaceWhite,
        error: AppColors.errorRed,
        onError: AppColors.surfaceWhite,
        surface: AppColors.surfaceWhite,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.lightPink,
        outline: AppColors.borderSubtle,
        outlineVariant: AppColors.dividerColor,
      ),

      // Typography
      textTheme: baseTextTheme,

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.primaryNavy,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1.0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(
          color: AppColors.primaryNavy,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.primaryNavy,
          size: 24.0,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // Card Theme (Border radius 24.0, subtle drop shadows: Color(0x0A000000), blurRadius: 16, offset: (0, 8))
      cardTheme: CardThemeData(
        color: AppColors.surfaceWhite,
        elevation: 0,
        shadowColor: AppColors.cardShadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: const BorderSide(
            color: AppColors.borderSubtle,
            width: 1.0,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      ),

      // Elevated Button Theme (primaryNavy, border radius 24.0, 52px height)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryNavy,
          foregroundColor: AppColors.surfaceWhite,
          elevation: 0,
          minimumSize: const Size.fromHeight(52.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          textStyle: GoogleFonts.cairo(
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
            color: AppColors.surfaceWhite,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryNavy,
          minimumSize: const Size.fromHeight(52.0),
          side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          textStyle: GoogleFonts.cairo(
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryNavy,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondaryPink,
          textStyle: GoogleFonts.cairo(
            fontSize: 14.0,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.8),
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceWhite,
        selectedItemColor: AppColors.secondaryPink,
        unselectedItemColor: AppColors.textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightPink,
        selectedColor: AppColors.secondaryPink,
        disabledColor: AppColors.borderSubtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide.none,
        ),
        labelStyle: GoogleFonts.cairo(
          fontSize: 13.0,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryNavy,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        titleTextStyle: AppTextStyles.headlineSmall,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerColor,
        thickness: 1.0,
        space: 24.0,
      ),
    );
  }
}
