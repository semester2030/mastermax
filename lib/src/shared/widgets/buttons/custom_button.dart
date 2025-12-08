import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isDisabled;
  final double? width;
  final double? height;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    required this.text, required this.onPressed, super.key,
    this.isLoading = false,
    this.isOutlined = false,
    this.isDisabled = false,
    this.width,
    this.height,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 48,
      child: isOutlined ? _buildOutlinedButton() : _buildElevatedButton(),
    );
  }

  Widget _buildElevatedButton() {
    return ElevatedButton(
      onPressed: isDisabled || isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.lightBlue,
        foregroundColor: _getTextColor(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        shadowColor: ColorUtils.withOpacity(AppColors.lightBlue, 0.3),
      ),
      child: _buildButtonContent(),
    );
  }

  Widget _buildOutlinedButton() {
    return OutlinedButton(
      onPressed: isDisabled || isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.lightBlue,
        side: BorderSide(
          color: isDisabled ? AppColors.lightGray : AppColors.lightBlue,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _buildButtonContent(),
    );
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
            isOutlined ? AppColors.lightBlue : AppColors.white,
                ),
              ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
              text,
            style: TextStyle(
              fontSize: 16,
                fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              color: isDisabled
                  ? AppColors.darkGray
                  : (isOutlined ? AppColors.lightBlue : _getTextColor()),
              ),
            ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        fontFamily: 'Cairo',
        color: isDisabled
            ? AppColors.darkGray
            : (isOutlined ? AppColors.lightBlue : _getTextColor()),
      ),
    );
  }

  Color _getTextColor() {
    final isBlue = backgroundColor == AppColors.primary ||
        backgroundColor == AppColors.lightBlue ||
        backgroundColor == AppColors.accent ||
        backgroundColor == AppColors.secondary ||
        backgroundColor == const Color(0xFF1E3A8A) ||
        backgroundColor == const Color(0xFF000B3B);
    if (isBlue) {
      return AppColors.white;
    }
    return textColor ?? AppColors.white;
  }
} 