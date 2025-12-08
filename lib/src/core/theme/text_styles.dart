import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../utils/color_utils.dart';

class TextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.25,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.text,
    letterSpacing: 0.15,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.text,
    letterSpacing: 0.15,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.surface,
    letterSpacing: 0.15,
  );

  static const TextStyle link = TextStyle(
    fontSize: 16,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
    letterSpacing: 0.15,
  );

  static const TextStyle error = TextStyle(
    fontSize: 14,
    color: AppColors.error,
    letterSpacing: 0.1,
  );

  static const TextStyle success = TextStyle(
    fontSize: 14,
    color: AppColors.success,
    letterSpacing: 0.1,
  );
}

class AppStyles {
  // Text Styles
  static TextStyle get heading1 => TextStyles.heading1;
  static TextStyle get heading2 => TextStyles.heading2;
  static TextStyle get heading3 => TextStyles.heading3;
  static TextStyle get body => TextStyles.body;
  static TextStyle get bodyBold => TextStyles.bodyBold;
  static TextStyle get caption => TextStyles.caption;
  static TextStyle get button => TextStyles.button;
  static TextStyle get link => TextStyles.link;
  static TextStyle get error => TextStyles.error;
  static TextStyle get success => TextStyles.success;

  // Color Styles
  static Color get primary => AppColors.primary;
  static Color get secondary => AppColors.secondary;
  static Color get accent => AppColors.accent;
  static Color get text => AppColors.text;
  static Color get textLight => AppColors.textLight;
  static Color get textMuted => AppColors.textMuted;
  static Color get background => AppColors.background;
  static Color get surface => AppColors.surface;
  static Color get divider => AppColors.divider;
  static Color get border => AppColors.border;
  static Color get disabled => AppColors.disabled;
  static Color get shadow => AppColors.shadow;
  static Color get glass => AppColors.surface;
  static Color get glassLight => AppColors.surface;
  
  // Decorations
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: AppColors.defaultShadow,
  );

  static BoxDecoration get modalDecoration => BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(24),
    boxShadow: AppColors.largeShadow,
  );

  static BoxDecoration get buttonDecoration => BoxDecoration(
    color: AppColors.primary,
    borderRadius: BorderRadius.circular(16),
    boxShadow: AppColors.defaultShadow,
  );

  static BoxDecoration get outlinedButtonDecoration => BoxDecoration(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.primary),
  );

  static BoxDecoration get glassDecoration => BoxDecoration(
    color: ColorUtils.withOpacity(AppColors.surface, 0.18),
    borderRadius: BorderRadius.circular(20),
    gradient: AppColors.royalMetallicGradient,
    boxShadow: AppColors.defaultShadow,
  );

  static BoxDecoration get lightGlassDecoration => BoxDecoration(
    color: ColorUtils.withOpacity(AppColors.surface, 0.08),
    borderRadius: BorderRadius.circular(20),
  );
} 