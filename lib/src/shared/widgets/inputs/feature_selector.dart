import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class FeatureSelector extends StatefulWidget {
  final List<String> selectedFeatures;
  final void Function(List<String>) onChanged;

  const FeatureSelector({
    required this.selectedFeatures, required this.onChanged, super.key,
  });

  @override
  State<FeatureSelector> createState() => _FeatureSelectorState();
}

class _FeatureSelectorState extends State<FeatureSelector> {
  // Predefined list of common car features
  final List<String> _availableFeatures = [
    'مكيف',
    'نظام فرامل ABS',
    'وسائد هوائية',
    'مثبت سرعة',
    'كاميرا خلفية',
    'حساسات خلفية',
    'نظام ملاحة',
    'بلوتوث',
    'مقاعد جلد',
    'مقاعد كهربائية',
    'فتحة سقف',
    'جنوط',
    'مصابيح LED',
    'مصابيح ضباب',
    'نظام صوتي فاخر',
    'شاشة لمس',
    'تحكم بالمقود',
    'زجاج كهربائي',
    'مرايا كهربائية',
    'تكييف خلفي',
    'حساسات أمامية',
    'كاميرا 360',
    'نظام مراقبة النقطة العمياء',
    'نظام التحكم بالمسار',
  ];

  void _toggleFeature(String feature) {
    final List<String> newFeatures = List.from(widget.selectedFeatures);
    if (newFeatures.contains(feature)) {
      newFeatures.remove(feature);
    } else {
      newFeatures.add(feature);
    }
    widget.onChanged(newFeatures);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableFeatures.map((feature) {
        final isSelected = widget.selectedFeatures.contains(feature);
        return FilterChip(
          label: Text(feature),
          selected: isSelected,
          onSelected: (_) => _toggleFeature(feature),
          selectedColor: ColorUtils.withOpacity(AppColors.primary, 0.1),
          checkmarkColor: AppColors.primary,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : Colors.black,
            fontSize: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? AppColors.primary : Colors.grey[300]!,
            ),
          ),
          backgroundColor: Colors.white,
        );
      }).toList(),
    );
  }
} 