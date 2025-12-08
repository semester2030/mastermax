import 'package:flutter/material.dart';
import '../../../core/utils/color_utils.dart';

class PriceFilterContent extends StatefulWidget {
  const PriceFilterContent({super.key});

  @override
  State<PriceFilterContent> createState() => _PriceFilterContentState();
}

class _PriceFilterContentState extends State<PriceFilterContent> {
  RangeValues _currentRangeValues = const RangeValues(0, 1000000);
  bool _isForSale = true;
  bool _isForRent = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // نوع العملية
        Text(
          'نوع العملية',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildOperationTypeChip(
              label: 'بيع',
              isSelected: _isForSale,
              onTap: () => setState(() {
                _isForSale = true;
                _isForRent = false;
              }),
            ),
            const SizedBox(width: 12),
            _buildOperationTypeChip(
              label: 'إيجار',
              isSelected: _isForRent,
              onTap: () => setState(() {
                _isForSale = false;
                _isForRent = true;
              }),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // نطاق السعر
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'نطاق السعر',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_currentRangeValues.start.round()} - ${_currentRangeValues.end.round()} ريال',
              style: textTheme.bodySmall?.copyWith(
                color: ColorUtils.withOpacity(colorScheme.onPrimary, 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: _currentRangeValues,
          max: 1000000,
          divisions: 100,
          activeColor: colorScheme.secondary,
          inactiveColor: ColorUtils.withOpacity(colorScheme.secondary, 0.3),
          labels: RangeLabels(
            '${_currentRangeValues.start.round()} ريال',
            '${_currentRangeValues.end.round()} ريال',
          ),
          onChanged: (RangeValues values) {
            setState(() {
              _currentRangeValues = values;
            });
          },
        ),

        // أزرار التحكم
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.withOpacity(colorScheme.onPrimary, 0.24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'إلغاء',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
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
                  backgroundColor: colorScheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'تطبيق',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSecondary,
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

  Widget _buildOperationTypeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.secondary : ColorUtils.withOpacity(colorScheme.onPrimary, 0.24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: textTheme.titleMedium?.copyWith(
            color: isSelected ? colorScheme.onSecondary : colorScheme.onPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
} 