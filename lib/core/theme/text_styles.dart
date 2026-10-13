import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Complete Arabic RTL typography system utilizing Google Fonts Cairo.
abstract final class AppTextStyles {
  // Font Family Identifier
  static const String fontFamily = 'Cairo';

  // Display Styles (Onboarding, Hero banners, Marketing)
  static TextStyle get displayLarge => GoogleFonts.cairo(
        fontSize: 32.0,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.35,
      );

  static TextStyle get displayMedium => GoogleFonts.cairo(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.35,
      );

  static TextStyle get displaySmall => GoogleFonts.cairo(
        fontSize: 24.0,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.35,
      );

  // Headline Styles (Section headers, Modal titles)
  static TextStyle get headlineLarge => GoogleFonts.cairo(
        fontSize: 22.0,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get headlineMedium => GoogleFonts.cairo(
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get headlineSmall => GoogleFonts.cairo(
        fontSize: 18.0,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  // Title Styles (Card headers, Profile names)
  static TextStyle get titleLarge => GoogleFonts.cairo(
        fontSize: 17.0,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get titleMedium => GoogleFonts.cairo(
        fontSize: 15.0,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get titleSmall => GoogleFonts.cairo(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // Body Styles (Paragraphs, Bios, Form fields)
  static TextStyle get bodyLarge => GoogleFonts.cairo(
        fontSize: 15.0,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.cairo(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.cairo(
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  // Label & Action Styles (Buttons, Badges, Tabs)
  static TextStyle get labelLarge => GoogleFonts.cairo(
        fontSize: 15.0,
        fontWeight: FontWeight.w700,
        color: AppColors.surfaceWhite,
        height: 1.3,
      );

  static TextStyle get labelMedium => GoogleFonts.cairo(
        fontSize: 13.0,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get labelSmall => GoogleFonts.cairo(
        fontSize: 11.0,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        height: 1.3,
      );

  /// Generates the complete [TextTheme] based on Cairo.
  static TextTheme get textTheme => GoogleFonts.cairoTextTheme(
        TextTheme(
          displayLarge: displayLarge,
          displayMedium: displayMedium,
          displaySmall: displaySmall,
          headlineLarge: headlineLarge,
          headlineMedium: headlineMedium,
          headlineSmall: headlineSmall,
          titleLarge: titleLarge,
          titleMedium: titleMedium,
          titleSmall: titleSmall,
          bodyLarge: bodyLarge,
          bodyMedium: bodyMedium,
          bodySmall: bodySmall,
          labelLarge: labelLarge,
          labelMedium: labelMedium,
          labelSmall: labelSmall,
        ),
      );
}
