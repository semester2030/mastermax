import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final double iconSize;
  final double spacing;

  const EmptyState({
    required this.title, required this.message, required this.icon, super.key,
    this.buttonText,
    this.onButtonPressed,
    this.iconSize = 80,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: ColorUtils.withOpacity(AppColors.darkGray, 0.5),
            ),
            SizedBox(height: spacing),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: AppColors.darkGray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Cairo',
                color: AppColors.darkGray,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              SizedBox(height: spacing),
              ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightBlue,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  buttonText!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NoPropertiesView extends StatelessWidget {
  final VoidCallback? onAddPressed;

  const NoPropertiesView({
    super.key,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'لا توجد عقارات',
      message: 'لم يتم إضافة أي عقارات حتى الآن',
      icon: Icons.home_work,
      onButtonPressed: onAddPressed,
      buttonText: 'إضافة عقار',
    );
  }
}

class NoCarsView extends StatelessWidget {
  final VoidCallback? onAddPressed;

  const NoCarsView({
    super.key,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'لا توجد سيارات',
      message: 'لم يتم إضافة أي سيارات حتى الآن',
      icon: Icons.directions_car,
      onButtonPressed: onAddPressed,
      buttonText: 'إضافة سيارة',
    );
  }
}

class NoVideosView extends StatelessWidget {
  final VoidCallback? onAddPressed;

  const NoVideosView({
    super.key,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'لا توجد فيديوهات',
      message: 'لم يتم إضافة أي فيديوهات حتى الآن',
      icon: Icons.videocam,
      onButtonPressed: onAddPressed,
      buttonText: 'إضافة فيديو',
    );
  }
}

class NoChatsView extends StatelessWidget {
  const NoChatsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'لا توجد محادثات',
      message: 'لم تبدأ أي محادثات حتى الآن',
      icon: Icons.chat_bubble,
    );
  }
}

class NoNotificationsView extends StatelessWidget {
  const NoNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'لا توجد إشعارات',
      message: 'ليس لديك أي إشعارات حتى الآن',
      icon: Icons.notifications,
    );
  }
} 