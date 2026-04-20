import 'package:flutter/material.dart';
import '../../../src/core/theme/app_colors.dart';

class OrphanedVideosScreen extends StatelessWidget {
  const OrphanedVideosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text(
                  'فيديوهات يتيمة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'هذه الميزة تحتاج تشغيل من التطبيق (موبايل) لاستدعاء خدمة FindOrphaned. في لوحة الويب يمكن إضافة استدعاء Cloud Function لاحقاً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
