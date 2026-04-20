import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/property_model.dart';
import 'property_form_helpers.dart';

/// Widget لعرض قسم تفاصيل الإيجار
///
/// يعرض حقول خاصة بالإيجار (الإيجار الشهري، المرافق، فترة الإيجار، نوع الإيجار)
/// يظهر فقط عند اختيار "إيجار" كنوع العرض
/// يتبع الثيم الموحد للتطبيق
class PropertyRentalDetailsSection extends StatefulWidget {
  final TextEditingController monthlyRentController;
  final TextEditingController? yearlyRentController; // ✅ إيجار سنوي
  final bool includesUtilities;
  final String? selectedMinimumRentPeriod;
  final RentalType? selectedRentalType;
  final ValueChanged<bool> onIncludesUtilitiesChanged;
  final ValueChanged<String?> onMinimumRentPeriodChanged;
  final ValueChanged<RentalType?> onRentalTypeChanged;
  final VoidCallback? onChanged;

  const PropertyRentalDetailsSection({
    super.key,
    required this.monthlyRentController,
    this.yearlyRentController, // ✅ إيجار سنوي (اختياري)
    required this.includesUtilities,
    required this.selectedMinimumRentPeriod,
    required this.selectedRentalType,
    required this.onIncludesUtilitiesChanged,
    required this.onMinimumRentPeriodChanged,
    required this.onRentalTypeChanged,
    this.onChanged,
  });

  @override
  State<PropertyRentalDetailsSection> createState() => _PropertyRentalDetailsSectionState();
}

class _PropertyRentalDetailsSectionState extends State<PropertyRentalDetailsSection> {
  bool _isExpanded = true;

  final List<String> _minimumRentPeriods = [
    '1 شهر',
    '3 أشهر',
    '6 أشهر',
    '12 شهر',
    '24 شهر',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: propertySectionCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.home_work, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'تفاصيل الإيجار',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ نص مساعد
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: propertyFormInfoBannerDecoration(),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'املأ تفاصيل الإيجار لتحسين جودة العرض',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ✅ نوع الإيجار (تجاري/سكني)
                  PropertySectionTitle(title: 'نوع الإيجار'),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<RentalType>(
                          title: const Text(
                            'إيجار سكني',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                          value: RentalType.residential,
                          groupValue: widget.selectedRentalType,
                          activeColor: AppColors.primary,
                          onChanged: (value) {
                            widget.onRentalTypeChanged(value);
                            widget.onChanged?.call();
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<RentalType>(
                          title: const Text(
                            'إيجار تجاري',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                          value: RentalType.commercial,
                          groupValue: widget.selectedRentalType,
                          activeColor: AppColors.primary,
                          onChanged: (value) {
                            widget.onRentalTypeChanged(value);
                            widget.onChanged?.call();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ✅ الإيجار الشهري والسنوي
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PropertySectionTitle(title: 'الإيجار الشهري'),
                            TextFormField(
                              controller: widget.monthlyRentController,
                              decoration: getPropertyInputDecoration(
                                'الإيجار الشهري',
                                hint: 'مثال: 5000',
                                prefixIcon: Icons.calendar_month,
                              ).copyWith(
                                suffixText: 'ريال',
                                suffixStyle: const TextStyle(color: AppColors.textPrimary),
                              ),
                              style: const TextStyle(color: AppColors.textPrimary),
                              keyboardType: TextInputType.number,
                              onChanged: (_) {
                                // ✅ حساب الإيجار السنوي تلقائياً
                                if (widget.yearlyRentController != null) {
                                  final monthly = double.tryParse(widget.monthlyRentController.text) ?? 0;
                                  if (monthly > 0) {
                                    widget.yearlyRentController!.text = (monthly * 12).toStringAsFixed(0);
                                  }
                                }
                                widget.onChanged?.call();
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'مطلوب';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'رقم صحيح';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PropertySectionTitle(title: 'الإيجار السنوي'),
                            TextFormField(
                              controller: widget.yearlyRentController,
                              decoration: getPropertyInputDecoration(
                                'الإيجار السنوي',
                                hint: 'مثال: 60000',
                                prefixIcon: Icons.calendar_today,
                              ).copyWith(
                                suffixText: 'ريال',
                                suffixStyle: const TextStyle(color: AppColors.textPrimary),
                              ),
                              style: const TextStyle(color: AppColors.textPrimary),
                              keyboardType: TextInputType.number,
                              onChanged: (_) {
                                // ✅ حساب الإيجار الشهري تلقائياً
                                final yearly = double.tryParse(widget.yearlyRentController?.text ?? '') ?? 0;
                                if (yearly > 0) {
                                  widget.monthlyRentController.text = (yearly / 12).toStringAsFixed(0);
                                }
                                widget.onChanged?.call();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: propertyFormInfoBannerDecoration(borderRadius: 4),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'سيتم حساب القيمة الأخرى تلقائياً',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ✅ الحد الأدنى لفترة الإيجار
                  PropertySectionTitle(title: 'الحد الأدنى لفترة الإيجار'),
                  PropertyDropdown(
                    value: widget.selectedMinimumRentPeriod,
                    items: _minimumRentPeriods,
                    hint: 'اختر الحد الأدنى لفترة الإيجار',
                    onChanged: (value) {
                      widget.onMinimumRentPeriodChanged(value);
                      widget.onChanged?.call();
                    },
                  ),
                  const SizedBox(height: 16),
                  // ✅ يشمل المرافق
                  PropertyFeatureSwitch(
                    title: 'يشمل المرافق (كهرباء، ماء، إنترنت)',
                    value: widget.includesUtilities,
                    onChanged: (value) {
                      widget.onIncludesUtilitiesChanged(value);
                      widget.onChanged?.call();
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
