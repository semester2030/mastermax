import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import 'property_form_helpers.dart';

/// Widget لعرض قسم المميزات
///
/// يعرض Dropdowns و Switches للمميزات
/// يتبع الثيم الموحد للتطبيق
class PropertyFeaturesSection extends StatelessWidget {
  final String? selectedKitchenType;
  final String? selectedFinishingType;
  final String? selectedView;
  final int selectedFloor;
  final bool hasElevator;
  final bool hasAC;
  final bool hasCentralAC;
  final bool hasInternetService;
  final bool hasGarage;
  final bool hasGarden;
  final bool hasPool;
  final bool hasSecurity;
  final List<String> kitchenTypes;
  final List<String> finishingTypes;
  final List<String> viewTypes;
  final ValueChanged<String?> onKitchenTypeChanged;
  final ValueChanged<String?> onFinishingTypeChanged;
  final ValueChanged<String?> onViewChanged;
  final ValueChanged<int> onFloorChanged;
  final ValueChanged<bool> onHasElevatorChanged;
  final ValueChanged<bool> onHasACChanged;
  final ValueChanged<bool> onHasCentralACChanged;
  final ValueChanged<bool> onHasInternetServiceChanged;
  final ValueChanged<bool> onHasGarageChanged;
  final ValueChanged<bool> onHasGardenChanged;
  final ValueChanged<bool> onHasPoolChanged;
  final ValueChanged<bool> onHasSecurityChanged;

  const PropertyFeaturesSection({
    super.key,
    required this.selectedKitchenType,
    required this.selectedFinishingType,
    required this.selectedView,
    required this.selectedFloor,
    required this.hasElevator,
    required this.hasAC,
    required this.hasCentralAC,
    required this.hasInternetService,
    required this.hasGarage,
    required this.hasGarden,
    required this.hasPool,
    required this.hasSecurity,
    required this.kitchenTypes,
    required this.finishingTypes,
    required this.viewTypes,
    required this.onKitchenTypeChanged,
    required this.onFinishingTypeChanged,
    required this.onViewChanged,
    required this.onFloorChanged,
    required this.onHasElevatorChanged,
    required this.onHasACChanged,
    required this.onHasCentralACChanged,
    required this.onHasInternetServiceChanged,
    required this.onHasGarageChanged,
    required this.onHasGardenChanged,
    required this.onHasPoolChanged,
    required this.onHasSecurityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المميزات',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(AppColors.white, 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryLight),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: selectedKitchenType,
                decoration: getPropertyInputDecoration('نوع المطبخ'),
                dropdownColor: AppColors.background,
                style: const TextStyle(color: AppColors.textPrimary),
                items: kitchenTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: onKitchenTypeChanged,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedFinishingType,
                decoration: getPropertyInputDecoration('مستوى التشطيب'),
                dropdownColor: AppColors.background,
                style: const TextStyle(color: AppColors.textPrimary),
                items: finishingTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: onFinishingTypeChanged,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedView,
                decoration: getPropertyInputDecoration('الإطلالة'),
                dropdownColor: AppColors.background,
                style: const TextStyle(color: AppColors.textPrimary),
                items: viewTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: onViewChanged,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: selectedFloor.toString(),
                decoration: getPropertyInputDecoration('الطابق'),
                style: const TextStyle(color: AppColors.textPrimary),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  onFloorChanged(int.tryParse(value) ?? 0);
                },
              ),
              const SizedBox(height: 16),
              PropertyFeatureSwitch(
                title: 'مصعد',
                value: hasElevator,
                onChanged: onHasElevatorChanged,
              ),
              PropertyFeatureSwitch(
                title: 'تكييف',
                value: hasAC,
                onChanged: onHasACChanged,
              ),
              PropertyFeatureSwitch(
                title: 'تكييف مركزي',
                value: hasCentralAC,
                onChanged: onHasCentralACChanged,
              ),
              PropertyFeatureSwitch(
                title: 'خدمة إنترنت',
                value: hasInternetService,
                onChanged: onHasInternetServiceChanged,
              ),
              PropertyFeatureSwitch(
                title: 'موقف سيارات',
                value: hasGarage,
                onChanged: onHasGarageChanged,
              ),
              PropertyFeatureSwitch(
                title: 'حديقة',
                value: hasGarden,
                onChanged: onHasGardenChanged,
              ),
              PropertyFeatureSwitch(
                title: 'مسبح',
                value: hasPool,
                onChanged: onHasPoolChanged,
              ),
              PropertyFeatureSwitch(
                title: 'حراسة أمنية',
                value: hasSecurity,
                onChanged: onHasSecurityChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
