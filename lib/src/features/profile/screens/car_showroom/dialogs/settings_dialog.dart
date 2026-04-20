import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// Dialog لعرض الإعدادات
///
/// يعرض قائمة بخيارات الإعدادات
/// يتبع الثيم الموحد للتطبيق
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
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
              Icons.settings,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Text('الإعدادات'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SettingsItem(
            title: 'اللغة',
            icon: Icons.language_outlined,
            subtitle: 'تغيير لغة التطبيق',
            onTap: () {
              // TODO: Handle language settings
            },
          ),
          const SizedBox(height: 8),
          _SettingsItem(
            title: 'الإشعارات',
            icon: Icons.notifications_outlined,
            subtitle: 'إدارة إعدادات الإشعارات',
            onTap: () {
              // TODO: Handle notification settings
            },
          ),
          const SizedBox(height: 8),
          _SettingsItem(
            title: 'الأمان',
            icon: Icons.security_outlined,
            subtitle: 'إعدادات الأمان والخصوصية',
            onTap: () {
              // TODO: Handle security settings
            },
          ),
        ],
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
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.primaryLight,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: AppColors.primary,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}
