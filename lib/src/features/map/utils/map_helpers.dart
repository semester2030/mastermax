import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

/// Helper functions للخريطة
/// 
/// يحتوي على دوال مساعدة مشتركة بين مكونات الخريطة
class MapHelpers {
  /// ✅ إجراء مكالمة هاتفية
  /// 
  /// يفتح تطبيق الهاتف لإجراء مكالمة للرقم المحدد
  static Future<void> launchPhoneCall(String? phone, BuildContext context) async {
    if (phone?.isEmpty ?? true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رقم الهاتف غير متوفر'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final Uri url = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح تطبيق الهاتف'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة الاتصال: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
