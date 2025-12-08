import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class CarFeaturesSection extends StatelessWidget {
  final List<String> features;

  const CarFeaturesSection({
    required this.features, super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المميزات',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: features.map((feature) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ColorUtils.withOpacity(AppColors.accent, 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ColorUtils.withOpacity(AppColors.accent, 0.3),
                ),
              ),
              child: Text(
                feature,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
} 