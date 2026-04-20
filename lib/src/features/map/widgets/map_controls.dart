import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Widget لأزرار التحكم في الخريطة
///
/// يعرض زر التحكم في وضع 3D
/// يتبع الثيم الموحد للتطبيق
class MapControls extends StatelessWidget {
  final bool isPortrait;
  final bool is3DMode;
  final VoidCallback onToggle3D;

  const MapControls({
    super.key,
    required this.isPortrait,
    required this.is3DMode,
    required this.onToggle3D,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: isPortrait ? MediaQuery.of(context).size.height * 0.45 + 16 : 16,
      right: 16,
      child: FloatingActionButton(
        heroTag: '3d',
        onPressed: onToggle3D,
        backgroundColor: AppColors.primary,
        child: Icon(
          is3DMode ? Icons.view_in_ar : Icons.map,
          color: AppColors.white,
        ),
      ),
    );
  }
}
