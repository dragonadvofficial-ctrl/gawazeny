import 'package:flutter/material.dart';

/// Design tokens and brand color palette for the "جوزيني يا ماما" platform.
abstract final class AppColors {
  // Brand Core Colors
  static const Color primaryNavy = Color(0xFF0F2D5B);
  static const Color secondaryPink = Color(0xFFE9477A);
  static const Color primaryBurgundy = Color(0xFF881337);
  static const Color goldAccent = Color(0xFFD4AF37);
  static const Color lightPink = Color(0xFFFADADC);
  static const Color ivoryBackground = Color(0xFFFFF7EE);
  static const Color offWhite = Color(0xFFFFF7EE);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  // Typography & Content Colors
  static const Color textPrimary = Color(0xFF0F2D5B);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textMuted = Color(0xFF9E9E9E);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Semantic & Feedback Colors
  static const Color successGreen = Color(0xFF28A745);
  static const Color errorRed = Color(0xFFDC3545);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color infoBlue = Color(0xFF17A2B8);

  // Component & Surface Variants
  static const Color borderSubtle = Color(0xFFE8E9EC);
  static const Color borderFocused = Color(0xFF0F2D5B);
  static const Color dividerColor = Color(0xFFEEEEEE);
  static const Color cardShadowColor = Color(0x0A000000);
  static const Color overlayDark = Color(0x73000000);
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryNavy, Color(0xFF1B498A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [secondaryPink, Color(0xFFFF6F99)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmBackgroundGradient = LinearGradient(
    colors: [offWhite, Color(0xFFFFF7F8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
