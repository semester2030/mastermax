import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';

/// Widgets مشتركة تستخدم في فلاتر العقارات والسيارات

/// عنوان القسم
class FilterSectionTitle extends StatelessWidget {
  final String title;

  const FilterSectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// قائمة منسدلة مخصصة
class FilterDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String hint;
  final ValueChanged<String?> onChanged;

  const FilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        )).toList(),
        onChanged: onChanged,
        hint: Text(
          hint,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
        isExpanded: true,
        dropdownColor: AppColors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// شريط نطاق القيم (Range Slider)
class FilterRangeSlider extends StatelessWidget {
  final RangeValues values;
  final double min;
  final double max;
  final int divisions;
  final String startLabel;
  final String endLabel;
  final String minLabel;
  final String maxLabel;
  final ValueChanged<RangeValues> onChanged;

  const FilterRangeSlider({
    super.key,
    required this.values,
    required this.min,
    required this.max,
    required this.divisions,
    required this.startLabel,
    required this.endLabel,
    required this.minLabel,
    required this.maxLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.primary,
          inactiveColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
          labels: RangeLabels(startLabel, endLabel),
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              minLabel,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              maxLabel,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// شريط نطاق مع عنوان
class FilterRangeSliderWithTitle extends StatelessWidget {
  final String title;
  final RangeValues values;
  final double min;
  final double max;
  final ValueChanged<RangeValues> onChanged;
  final String singularLabel;
  final String pluralLabel;

  const FilterRangeSliderWithTitle({
    super.key,
    required this.title,
    required this.values,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.singularLabel,
    required this.pluralLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: max.toInt(),
          activeColor: AppColors.primary,
          inactiveColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
          labels: RangeLabels(
            '${values.start.round()} $singularLabel',
            '${values.end.round()} $pluralLabel',
          ),
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$min $singularLabel',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              '${max.toInt()} $pluralLabel',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// مفتاح تبديل مع أيقونة
class FilterSwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  const FilterSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Row(
        children: [
          Icon(
            icon ?? Icons.check_box,
            size: 20,
            color: value ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: value ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}

/// اختيار الموقع (المدينة والحي)
class LocationSelection extends StatelessWidget {
  final String? selectedCity;
  final String? selectedDistrict;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onDistrictChanged;
  final List<String> cities;
  final List<String> districts;

  const LocationSelection({
    super.key,
    required this.selectedCity,
    this.selectedDistrict,
    required this.onCityChanged,
    required this.onDistrictChanged,
    required this.cities,
    required this.districts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilterDropdown(
          value: selectedCity,
          items: cities,
          hint: 'اختر المدينة',
          onChanged: onCityChanged,
        ),
        if (selectedCity != null && districts.isNotEmpty) ...[
          const SizedBox(height: 8),
          FilterDropdown(
            value: selectedDistrict,
            items: districts,
            hint: 'اختر الحي',
            onChanged: onDistrictChanged,
          ),
        ],
      ],
    );
  }
}
