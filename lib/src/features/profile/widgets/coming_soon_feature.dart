import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// نص موحّد لخدمات «قيد التجهيز» (موبايل + ويب).
const String kComingSoonFeatureMessage =
    'هذه الخدمة قيد التجهيز وستُتاح قريباً. نعمل على إطلاقها — نشكر صبرك.';

/// حوار مناسب بدل SnackBar القصير في الملف الشخصي.
void showComingSoonFeatureDialog(BuildContext context, String featureTitle) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_outlined, color: AppColors.primary, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              featureTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        kComingSoonFeatureMessage,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

/// محتوى صفحة الويب لنفس الحالة (بدون Scaffold — يُلفّ بـ CarWebLayout).
class ComingSoonFeatureBody extends StatelessWidget {
  final String featureTitle;

  const ComingSoonFeatureBody({
    super.key,
    required this.featureTitle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 72,
            color: AppColors.primary,
          ),
          const SizedBox(height: 20),
          Text(
            featureTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            kComingSoonFeatureMessage,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
