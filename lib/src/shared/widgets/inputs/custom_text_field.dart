import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? prefix;
  final Widget? suffix;
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final bool autofocus;
  final bool showCursor;
  final String? initialValue;
  final bool expands;
  final TextCapitalization textCapitalization;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final InputBorder? border;
  final InputBorder? enabledBorder;
  final InputBorder? focusedBorder;
  final InputBorder? errorBorder;
  final InputBorder? focusedErrorBorder;
  final TextStyle? style;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final TextStyle? errorStyle;

  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.onTap,
    this.readOnly = false,
    this.prefix,
    this.suffix,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.focusNode,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.showCursor = true,
    this.initialValue,
    this.expands = false,
    this.textCapitalization = TextCapitalization.none,
    this.contentPadding,
    this.fillColor,
    this.border,
    this.enabledBorder,
    this.focusedBorder,
    this.errorBorder,
    this.focusedErrorBorder,
    this.style,
    this.labelStyle,
    this.hintStyle,
    this.errorStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      style: style ?? const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        hintStyle: hintStyle ?? const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        labelStyle: labelStyle ?? const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        errorStyle: errorStyle ?? const TextStyle(
          color: AppColors.error,
          fontSize: 12,
        ),
        prefixIcon: prefix,
        suffixIcon: suffix,
        contentPadding: contentPadding ?? const EdgeInsets.all(16),
        border: border ?? OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: enabledBorder ?? OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: focusedBorder ?? OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: errorBorder ?? OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: focusedErrorBorder ?? OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        filled: true,
        fillColor: fillColor ?? (enabled ? AppColors.background : AppColors.surface),
      ),
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      onTap: onTap,
      readOnly: readOnly,
      maxLines: maxLines,
      minLines: minLines,
      textInputAction: textInputAction,
      focusNode: focusNode,
      textDirection: textDirection,
      textAlign: textAlign,
      autofocus: autofocus,
      showCursor: showCursor,
      expands: expands,
      textCapitalization: textCapitalization,
    );
  }
} 