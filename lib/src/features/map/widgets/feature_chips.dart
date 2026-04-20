import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../../properties/models/property_model.dart';
import '../../cars/models/car_model.dart';

/// Helper functions لبناء feature chips للعقارات والسيارات
class FeatureChips {
  /// ✅ بناء feature chip
  static Widget buildFeatureChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(AppColors.primary, 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ بناء قائمة المميزات للعقار
  static Widget buildPropertyFeatures(PropertyModel property) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المميزات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            buildFeatureChip(
              icon: Icons.square_foot,
              label: '${property.area} م²',
            ),
            buildFeatureChip(
              icon: Icons.king_bed,
              label: '${property.rooms} غرف',
            ),
            buildFeatureChip(
              icon: Icons.bathtub,
              label: '${property.bathrooms} حمام',
            ),
            if (property.features['parking'] == true)
              buildFeatureChip(
                icon: Icons.local_parking,
                label: 'موقف سيارات',
              ),
            if (property.features['pool'] == true)
              buildFeatureChip(
                icon: Icons.pool,
                label: 'مسبح',
              ),
          ],
        ),
      ],
    );
  }

  /// ✅ بناء قائمة المواصفات للسيارة
  static Widget buildCarFeatures(CarModel car) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المواصفات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            buildFeatureChip(
              icon: Icons.calendar_today,
              label: '${car.year}',
            ),
            buildFeatureChip(
              icon: Icons.speed,
              label: '${car.kilometers} كم',
            ),
            buildFeatureChip(
              icon: Icons.local_gas_station,
              label: car.fuelType,
            ),
            buildFeatureChip(
              icon: Icons.settings,
              label: car.transmission,
            ),
            if (car.isVerified)
              buildFeatureChip(
                icon: Icons.verified,
                label: 'موثق',
              ),
          ],
        ),
      ],
    );
  }
}
