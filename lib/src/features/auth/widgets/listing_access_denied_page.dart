import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// صفحة بسيطة عند محاولة فتح مسار إضافة غير مسموح لنوع الحساب.
class ListingAccessDeniedPage extends StatelessWidget {
  final String message;

  const ListingAccessDeniedPage({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('غير متاح'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
