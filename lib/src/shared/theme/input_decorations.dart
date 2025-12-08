import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';

class AppInputDecorations {
  static InputDecoration authInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(prefixIcon, color: AppColors.darkGray),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brightRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brightRed, width: 2),
      ),
      filled: true,
      fillColor: AppColors.lightWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: const TextStyle(
        color: AppColors.darkGray,
        fontSize: 16,
        fontFamily: 'Cairo',
      ),
      errorStyle: const TextStyle(
        color: AppColors.brightRed,
        fontSize: 12,
        fontFamily: 'Cairo',
      ),
    );
  }

  static ButtonStyle elevatedButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.lightBlue,
      foregroundColor: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      shadowColor: ColorUtils.withOpacity(AppColors.lightBlue, 0.3),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        fontFamily: 'Cairo',
      ),
    );
  }

  static ButtonStyle outlinedButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.lightBlue,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: const BorderSide(color: AppColors.lightBlue),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        fontFamily: 'Cairo',
      ),
    );
  }
} 