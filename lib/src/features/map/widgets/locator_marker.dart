import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';

class LocatorMarker extends StatelessWidget {
  final LatLng position;
  final double? accuracy;
  final bool isMoving;

  const LocatorMarker({
    super.key,
    required this.position,
    this.accuracy,
    this.isMoving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // دائرة الدقة
        if (accuracy != null)
          Container(
            width: accuracy! * 2,
            height: accuracy! * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
        // Marker الرئيسي
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            border: Border.all(
              color: AppColors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isMoving
              ? const Icon(
                  Icons.navigation,
                  color: AppColors.white,
                  size: 12,
                )
              : null,
        ),
      ],
    );
  }
}

