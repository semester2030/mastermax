import 'package:flutter/material.dart';
import 'package:mastermax_2030/src/core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class AreaFilterContent extends StatefulWidget {
  const AreaFilterContent({super.key});

  @override
  State<AreaFilterContent> createState() => _AreaFilterContentState();
}

class _AreaFilterContentState extends State<AreaFilterContent> {
  RangeValues _currentRangeValues = const RangeValues(0, 1000);
  String _selectedPropertyType = 'شقة';

  final List<String> _propertyTypes = [
    'شقة',
    'فيلا',
    'أرض',
    'عمارة',
    'محل تجاري',
    'مكتب',
    'مستودع',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // نوع العقار
        Text(
          'نوع العقار',
          style: TextStyle(
            color: ColorUtils.withOpacity(AppColors.white, 0.9),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _propertyTypes.map((type) => _buildPropertyTypeChip(type)).toList(),
        ),
        const SizedBox(height: 24),

        // نطاق المساحة
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'نطاق المساحة',
              style: TextStyle(
                color: ColorUtils.withOpacity(AppColors.white, 0.9),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_currentRangeValues.start.round()} - ${_currentRangeValues.end.round()} متر مربع',
              style: TextStyle(
                color: ColorUtils.withOpacity(AppColors.white, 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: _currentRangeValues,
          max: 1000,
          divisions: 100,
          activeColor: AppColors.spotlightBorder,
          inactiveColor: ColorUtils.withOpacity(AppColors.spotlightBorder, 0.3),
          labels: RangeLabels(
            '${_currentRangeValues.start.round()} م²',
            '${_currentRangeValues.end.round()} م²',
          ),
          onChanged: (RangeValues values) {
            setState(() {
              _currentRangeValues = values;
            });
          },
        ),

        // معلومات إضافية
        const SizedBox(height: 24),
        Text(
          'معلومات إضافية',
          style: TextStyle(
            color: ColorUtils.withOpacity(AppColors.white, 0.9),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('عدد الغرف', '1 - 10+'),
        _buildInfoRow('عدد الحمامات', '1 - 7+'),
        _buildInfoRow('عدد الصالات', '1 - 5+'),
        _buildInfoRow('عمر العقار', '0 - 30+ سنة'),

        // أزرار التحكم
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.white.withOpacity(0.24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // تطبيق الفلتر
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spotlightBorder,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'تطبيق',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPropertyTypeChip(String type) {
    final isSelected = _selectedPropertyType == type;
    return InkWell(
      onTap: () => setState(() => _selectedPropertyType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.spotlightBorder : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          type,
          style: TextStyle(
            color: isSelected ? AppColors.textPrimary : AppColors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ColorUtils.withOpacity(AppColors.white, 0.7),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 