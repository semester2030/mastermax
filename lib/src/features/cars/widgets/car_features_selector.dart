import 'package:flutter/material.dart';
import '../models/car_features.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class CarFeaturesSelector extends StatefulWidget {
  final List<String> selectedFeatures;
  final Function(List<String>) onFeaturesChanged;

  const CarFeaturesSelector({
    required this.selectedFeatures, required this.onFeaturesChanged, super.key,
  });

  @override
  State<CarFeaturesSelector> createState() => _CarFeaturesSelectorState();
}

class _CarFeaturesSelectorState extends State<CarFeaturesSelector> {
  final Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    // جميع الفئات مغلقة في البداية
    for (var category in CarFeatures.categories.keys) {
      _expandedCategories[category] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'مميزات السيارة',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...CarFeatures.categories.entries.map((category) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: ColorUtils.withOpacity(AppColors.accent, 0.3),
              ),
            ),
            child: ExpansionTile(
              title: Text(
                category.key,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconColor: AppColors.accent,
              collapsedIconColor: AppColors.textLight,
              initiallyExpanded: _expandedCategories[category.key] ?? false,
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedCategories[category.key] = expanded;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: category.value.map((feature) {
                      final isSelected = widget.selectedFeatures.contains(feature);
                      return FilterChip(
                        label: Text(
                          feature,
                          style: TextStyle(
                            color: isSelected ? AppColors.text : AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          final newFeatures = List<String>.from(widget.selectedFeatures);
                          if (selected) {
                            newFeatures.add(feature);
                          } else {
                            newFeatures.remove(feature);
                          }
                          widget.onFeaturesChanged(newFeatures);
                        },
                        backgroundColor: AppColors.surface,
                        selectedColor: ColorUtils.withOpacity(AppColors.accent, 0.2),
                        checkmarkColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.accent : ColorUtils.withOpacity(AppColors.textLight, 0.3),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }),
        if (widget.selectedFeatures.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedFeatures.map((feature) {
              return Chip(
                label: Text(
                  feature,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                  ),
                ),
                backgroundColor: ColorUtils.withOpacity(AppColors.accent, 0.2),
                deleteIconColor: AppColors.accent,
                onDeleted: () {
                  final newFeatures = List<String>.from(widget.selectedFeatures)
                    ..remove(feature);
                  widget.onFeaturesChanged(newFeatures);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
} 