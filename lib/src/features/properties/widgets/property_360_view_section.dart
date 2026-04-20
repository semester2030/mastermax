import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import 'property_form_helpers.dart';

/// Widget لعرض قسم 360 view والجولة الافتراضية
///
/// يعرض Switch و TextField للـ 360 view و Virtual tour
/// يتبع الثيم الموحد للتطبيق
class Property360ViewSection extends StatelessWidget {
  final bool has360View;
  final String? virtualTourUrl;
  final ImagePicker imagePicker;
  final ValueChanged<bool> onHas360ViewChanged;
  final ValueChanged<String?> onVirtualTourUrlChanged;
  final ValueChanged<String?> onPanoramaUrlChanged;

  const Property360ViewSection({
    super.key,
    required this.has360View,
    required this.virtualTourUrl,
    required this.imagePicker,
    required this.onHas360ViewChanged,
    required this.onVirtualTourUrlChanged,
    required this.onPanoramaUrlChanged,
  });

  Future<void> _pick360Image(BuildContext context) async {
    try {
      final XFile? image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (image != null) {
        onPanoramaUrlChanged(image.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في اختيار الصورة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'العرض 360 والجولة الافتراضية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('عرض 360 درجة'),
          subtitle: const Text('إضافة عرض 360 درجة للعقار'),
          value: has360View,
          onChanged: (value) {
            onHas360ViewChanged(value);
            if (!value) {
              onPanoramaUrlChanged(null);
            }
          },
          activeColor: AppColors.primary,
        ),
        if (has360View)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => _pick360Image(context),
              icon: const Icon(Icons.view_in_ar),
              label: const Text('اختيار صورة 360 درجة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: getPropertyInputDecoration('رابط الجولة الافتراضية').copyWith(
            hintText: 'أدخل رابط الجولة الافتراضية (اختياري)',
            prefixIcon: const Icon(Icons.link, color: AppColors.primary),
          ),
          initialValue: virtualTourUrl,
          onChanged: (value) {
            onVirtualTourUrlChanged(value.isEmpty ? null : value);
          },
        ),
      ],
    );
  }
}
