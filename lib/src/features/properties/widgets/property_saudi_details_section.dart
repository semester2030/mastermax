import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'property_form_helpers.dart';

/// Widget لعرض قسم التفاصيل المهمة للعقارات في المملكة
///
/// يعرض حقول خاصة بالعقارات السعودية مع collapse/expand
/// يتبع الثيم الموحد للتطبيق
class PropertySaudiDetailsSection extends StatefulWidget {
  final bool hasApartments;
  final bool hasInternalStairs;
  final bool hasExternalStairs;
  final String? selectedPropertyDirection;
  final String? selectedStreetWidth;
  final TextEditingController livingRoomsCountController;
  final TextEditingController majlisCountController;
  final List<String> propertyDirections;
  final List<String> streetWidths;
  final ValueChanged<bool> onHasApartmentsChanged;
  final ValueChanged<bool> onHasInternalStairsChanged;
  final ValueChanged<bool> onHasExternalStairsChanged;
  final ValueChanged<String?> onPropertyDirectionChanged;
  final ValueChanged<String?> onStreetWidthChanged;

  const PropertySaudiDetailsSection({
    super.key,
    required this.hasApartments,
    required this.hasInternalStairs,
    required this.hasExternalStairs,
    required this.selectedPropertyDirection,
    required this.selectedStreetWidth,
    required this.livingRoomsCountController,
    required this.majlisCountController,
    required this.propertyDirections,
    required this.streetWidths,
    required this.onHasApartmentsChanged,
    required this.onHasInternalStairsChanged,
    required this.onHasExternalStairsChanged,
    required this.onPropertyDirectionChanged,
    required this.onStreetWidthChanged,
  });

  @override
  State<PropertySaudiDetailsSection> createState() => _PropertySaudiDetailsSectionState();
}

class _PropertySaudiDetailsSectionState extends State<PropertySaudiDetailsSection> {
  bool _isExpanded = true;

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
                      const Icon(Icons.location_city, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'تفاصيل مهمة للعقارات في المملكة',
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
                  PropertyFeatureSwitch(
                    title: 'الفيلا تحتوي على شقق منفصلة',
                    value: widget.hasApartments,
                    onChanged: widget.onHasApartmentsChanged,
                  ),
                  PropertyFeatureSwitch(
                    title: 'درج داخلي',
                    value: widget.hasInternalStairs,
                    onChanged: widget.onHasInternalStairsChanged,
                  ),
                  PropertyFeatureSwitch(
                    title: 'درج خارجي',
                    value: widget.hasExternalStairs,
                    onChanged: widget.onHasExternalStairsChanged,
                  ),
                  const SizedBox(height: 16),
                  PropertySectionTitle(title: 'اتجاه العقار'),
                  PropertyDropdown(
                    value: widget.selectedPropertyDirection,
                    items: widget.propertyDirections,
                    hint: 'اختر اتجاه العقار',
                    onChanged: widget.onPropertyDirectionChanged,
                  ),
                  const SizedBox(height: 16),
                  PropertySectionTitle(title: 'عرض الشارع'),
                  PropertyDropdown(
                    value: widget.selectedStreetWidth,
                    items: widget.streetWidths,
                    hint: 'اختر عرض الشارع',
                    onChanged: widget.onStreetWidthChanged,
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
