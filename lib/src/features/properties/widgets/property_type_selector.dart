import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../models/property_type.dart';

/// Widget لاختيار نوع العقار
///
/// يعرض Radio buttons لجميع أنواع العقارات
/// يتبع الثيم الموحد للتطبيق
class PropertyTypeSelector extends StatelessWidget {
  final PropertyType selectedType;
  final ValueChanged<PropertyType> onTypeChanged;

  const PropertyTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع العقار',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(AppColors.white, 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryLight),
          ),
          child: Column(
            children: PropertyType.values.map((type) {
              return RadioListTile<PropertyType>(
                title: Text(
                  type.toArabic(),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                value: type,
                groupValue: selectedType,
                activeColor: AppColors.primary,
                onChanged: (value) {
                  if (value != null) {
                    onTypeChanged(value);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
