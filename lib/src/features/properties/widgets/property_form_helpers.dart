import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

/// Widgets مساعدة لاستخدامها في نماذج العقارات
///
/// يحتوي على widgets صغيرة قابلة لإعادة الاستخدام
/// يتبع الثيم الموحد للتطبيق (نفس أسلوب `car_form`: سطح أبيض + حدود بنفسجية خفيفة).

/// بطاقة أقسام قابلة للطي — مطابقة لـ [CarForm] (`AppColors.surface` + حد شفاف).
BoxDecoration propertySectionCardDecoration({double borderRadius = 16}) {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: ColorUtils.withOpacity(AppColors.primary, 0.2),
    ),
  );
}

/// شريط معلومات داخل القسم (بدل طبقة primary الشديدة).
BoxDecoration propertyFormInfoBannerDecoration({double borderRadius = 8}) {
  return BoxDecoration(
    color: ColorUtils.withOpacity(AppColors.primary, 0.08),
    borderRadius: BorderRadius.circular(borderRadius),
  );
}

/// InputDecoration موحد لجميع حقول النموذج
InputDecoration getPropertyInputDecoration(
  String label, {
  String? hint,
  IconData? prefixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.primary) : null,
    labelStyle: const TextStyle(color: AppColors.textPrimary),
    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 153)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primaryLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primaryLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    filled: true,
    fillColor: AppColors.surface,
  );
}

/// عنوان قسم في النموذج
class PropertySectionTitle extends StatelessWidget {
  final String title;

  const PropertySectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Dropdown موحد للنماذج
class PropertyDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String hint;
  final ValueChanged<String?> onChanged;

  const PropertyDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryLight),
        color: AppColors.white,
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textSecondary),
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item, style: const TextStyle(color: AppColors.textPrimary)),
        )).toList(),
        onChanged: onChanged,
        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
        isExpanded: true,
        dropdownColor: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Switch موحد للمميزات
class PropertyFeatureSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const PropertyFeatureSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ColorUtils.withOpacity(AppColors.primary, 0.3),
          ),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}
