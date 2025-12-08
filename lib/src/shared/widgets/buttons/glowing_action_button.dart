import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class GlowingActionButton extends StatelessWidget {
  final Color color;
  final VoidCallback onPressed;
  final IconData icon;
  final double size;

  const GlowingActionButton({
    required this.color, required this.onPressed, required this.icon, super.key,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: ColorUtils.withOpacity(color, 0.3),
            spreadRadius: 8,
            blurRadius: 24,
          ),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            splashColor: ColorUtils.withOpacity(color, 0.2),
            highlightColor: ColorUtils.withOpacity(color, 0.4),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
} 