import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CustomDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T) itemText;
  final bool isExpanded;
  final bool isDense;
  final EdgeInsetsGeometry? contentPadding;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final bool isEnabled;

  const CustomDropdown({
    required this.hint, required this.value, required this.items, required this.onChanged, required this.itemText, super.key,
    this.isExpanded = true,
    this.isDense = true,
    this.contentPadding,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: isExpanded,
      isDense: isDense,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        errorText: errorText,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
      dropdownColor: AppColors.surface,
      items: items.map((T item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            itemText(item),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
        );
      }).toList(),
      onChanged: isEnabled ? onChanged : null,
    );
  }
} 