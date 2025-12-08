import 'package:flutter/material.dart';
import '../screens/camera_screen.dart';

class ModeSelector extends StatelessWidget {
  final CameraMode currentMode;
  final Function(CameraMode) onModeSelected;

  const ModeSelector({
    required this.currentMode, required this.onModeSelected, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton(
            context,
            CameraMode.normal,
            'عادي',
            Icons.camera_alt,
          ),
          _buildModeButton(
            context,
            CameraMode.panorama,
            '360°',
            Icons.panorama_horizontal,
          ),
          _buildModeButton(
            context,
            CameraMode.threeD,
            'ثلاثي الأبعاد',
            Icons.view_in_ar,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context,
    CameraMode mode,
    String label,
    IconData icon,
  ) {
    final isSelected = currentMode == mode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onModeSelected(mode),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white24 : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 