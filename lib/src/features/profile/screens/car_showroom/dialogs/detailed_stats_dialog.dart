import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// Dialog لعرض تفاصيل الإحصائية
///
/// يعرض معلومات تفصيلية عن الإحصائية المحددة
/// يتبع الثيم الموحد للتطبيق
class DetailedStatsDialog extends StatelessWidget {
  final String title;
  final String value;
  final String description;

  const DetailedStatsDialog({
    super.key,
    required this.title,
    required this.value,
    required this.description,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String value,
    required String description,
  }) {
    showDialog(
      context: context,
      builder: (context) => DetailedStatsDialog(
        title: title,
        value: value,
        description: description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          const Icon(Icons.analytics, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.primary),
            title: const Text('القيمة الحالية'),
            subtitle: Text(value),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined, color: AppColors.primary),
            title: const Text('الوصف'),
            subtitle: Text(description),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history, color: AppColors.primary),
            title: const Text('السجل التاريخي'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to historical data
            },
          ),
          ListTile(
            leading: const Icon(Icons.trending_up, color: AppColors.primary),
            title: const Text('التوقعات'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to predictions
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
