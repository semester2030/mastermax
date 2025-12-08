import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocate;

  const MapControls({
    required this.onZoomIn, required this.onZoomOut, required this.onLocate, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(
          icon: Icons.add,
          onPressed: onZoomIn,
        ),
        const SizedBox(height: 8),
        _buildButton(
          icon: Icons.remove,
          onPressed: onZoomOut,
        ),
        const SizedBox(height: 8),
        _buildButton(
          icon: Icons.my_location,
          onPressed: onLocate,
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.withOpacity(Colors.black, 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: AppColors.accent,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
} 