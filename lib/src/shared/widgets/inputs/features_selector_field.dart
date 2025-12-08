import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class FeaturesSelectorField extends StatelessWidget {
  final String label;
  final List<String> selectedFeatures;
  final List<String> availableFeatures;
  final Function(List<String>) onFeaturesChanged;
  final String? errorText;

  const FeaturesSelectorField({
    required this.label, required this.selectedFeatures, required this.availableFeatures, required this.onFeaturesChanged, super.key,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              if (selectedFeatures.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedFeatures.map((feature) {
                      return Chip(
                        label: Text(feature),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          final newFeatures = List<String>.from(selectedFeatures);
                          newFeatures.remove(feature);
                          onFeaturesChanged(newFeatures);
                        },
                        backgroundColor: ColorUtils.withOpacity(AppColors.primary, 0.1),
                        labelStyle: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                        deleteIconColor: AppColors.primary,
                      );
                    }).toList(),
                  ),
                ),
              if (selectedFeatures.isNotEmpty)
                const Divider(height: 1),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availableFeatures.length,
                itemBuilder: (context, index) {
                  final feature = availableFeatures[index];
                  final isSelected = selectedFeatures.contains(feature);
                  return ListTile(
                    title: Text(
                      feature,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    trailing: Icon(
                      isSelected ? Icons.check_circle : Icons.add_circle_outline,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    onTap: () {
                      final newFeatures = List<String>.from(selectedFeatures);
                      if (isSelected) {
                        newFeatures.remove(feature);
                      } else {
                        newFeatures.add(feature);
                      }
                      onFeaturesChanged(newFeatures);
                    },
                  );
                },
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
} 