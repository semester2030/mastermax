import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/property_model.dart';

/// Widget لاختيار نوع العرض (بيع/إيجار)
///
/// يعرض Radio buttons للبيع والإيجار
/// يتبع الثيم الموحد للتطبيق
class OfferTypeSelector extends StatelessWidget {
  final OfferType selectedType;
  final ValueChanged<OfferType> onTypeChanged;

  const OfferTypeSelector({
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
          'نوع العرض',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<OfferType>(
                title: const Text(
                  'بيع',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                value: OfferType.sale,
                groupValue: selectedType,
                activeColor: AppColors.primary,
                onChanged: (value) {
                  if (value != null) {
                    onTypeChanged(value);
                  }
                },
              ),
            ),
            Expanded(
              child: RadioListTile<OfferType>(
                title: const Text(
                  'إيجار',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                value: OfferType.rent,
                groupValue: selectedType,
                activeColor: AppColors.primary,
                onChanged: (value) {
                  if (value != null) {
                    onTypeChanged(value);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
