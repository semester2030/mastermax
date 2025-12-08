import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class DropdownMenu<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T) itemText;
  final Widget Function(T)? itemBuilder;
  final bool isExpanded;
  final bool isDense;
  final EdgeInsetsGeometry? contentPadding;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final bool isEnabled;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? textColor;
  final double? borderRadius;
  final double? elevation;

  const DropdownMenu({
    required this.hint, required this.value, required this.items, required this.onChanged, required this.itemText, super.key,
    this.itemBuilder,
    this.isExpanded = true,
    this.isDense = true,
    this.contentPadding,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.isEnabled = true,
    this.width,
    this.height,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius ?? 8),
        boxShadow: elevation != null
            ? [
                BoxShadow(
                  color: ColorUtils.withOpacity(AppColors.primary, 0.1),
                  blurRadius: elevation!,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: DropdownButtonFormField<T>(
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
          fillColor: backgroundColor ?? AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 8),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 8),
            borderSide: const BorderSide(color: AppColors.error),
          ),
        ),
        style: TextStyle(
          color: textColor ?? AppColors.textPrimary,
          fontSize: 14,
        ),
        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
        dropdownColor: backgroundColor ?? AppColors.surface,
        items: items.map((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: itemBuilder?.call(item) ??
                Text(
                  itemText(item),
                  style: TextStyle(
                    color: textColor ?? AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
          );
        }).toList(),
        onChanged: isEnabled ? onChanged : null,
      ),
    );
  }
} 