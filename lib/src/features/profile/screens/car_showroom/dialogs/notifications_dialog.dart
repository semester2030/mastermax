import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// Dialog لعرض الإشعارات
///
/// يعرض قائمة بالإشعارات
/// يتبع الثيم الموحد للتطبيق
class NotificationsDialog extends StatelessWidget {
  const NotificationsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NotificationsDialog(),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Text('الإشعارات'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: 5,
          itemBuilder: (context, index) {
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.primaryLight,
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(
                    Icons.notification_important_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'إشعار ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تفاصيل الإشعار ${index + 1}'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'منذ ${index + 1} ساعات',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    // TODO: Show notification options
                  },
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(
            Icons.close,
            color: AppColors.textPrimary,
            size: 20,
          ),
          label: const Text(
            'إغلاق',
            style: TextStyle(
              color: AppColors.textPrimary,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton.icon(
          icon: const Icon(
            Icons.check_circle_outline,
            color: AppColors.primary,
            size: 20,
          ),
          label: const Text(
            'تعليم الكل كمقروء',
            style: TextStyle(
              color: AppColors.primary,
            ),
          ),
          onPressed: () {
            // TODO: Mark all as read
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
