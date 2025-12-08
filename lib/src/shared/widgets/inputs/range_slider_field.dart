import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class RangeSliderField extends StatefulWidget {
  final String label;
  final double min;
  final double max;
  final RangeValues initialValue;
  final Function(RangeValues) onChanged;
  final String? Function(double)? valueFormatter;

  const RangeSliderField({
    required this.label, required this.min, required this.max, required this.initialValue, required this.onChanged, super.key,
    this.valueFormatter,
  });

  @override
  State<RangeSliderField> createState() => _RangeSliderFieldState();
}

class _RangeSliderFieldState extends State<RangeSliderField> {
  late RangeValues _currentRangeValues;
  final _numberFormat = NumberFormat('#,##0', 'ar');

  @override
  void initState() {
    super.initState();
    _currentRangeValues = widget.initialValue;
  }

  String _formatValue(double value) {
    if (widget.valueFormatter != null) {
      return widget.valueFormatter!(value) ?? _numberFormat.format(value);
    }
    return _numberFormat.format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.brightGold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatValue(_currentRangeValues.start),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.pureWhite,
              ),
            ),
            Text(
              _formatValue(_currentRangeValues.end),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.pureWhite,
              ),
            ),
          ],
        ),
        RangeSlider(
          values: _currentRangeValues,
          min: widget.min,
          max: widget.max,
          divisions: 100,
          activeColor: AppTheme.brightGold,
          inactiveColor: ColorUtils.withOpacity(AppTheme.brightGold, 0.3),
          labels: RangeLabels(
            _formatValue(_currentRangeValues.start),
            _formatValue(_currentRangeValues.end),
          ),
          onChanged: (RangeValues values) {
            setState(() {
              _currentRangeValues = values;
            });
            widget.onChanged(values);
          },
        ),
      ],
    );
  }
} 