import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CustomAlertDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool showCancelButton;
  final IconData? icon;

  const CustomAlertDialog({
    required this.title, required this.message, super.key,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.showCancelButton = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      icon: icon != null ? Icon(icon, size: 48) : null,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
          color: AppColors.deepBlue,
        ),
        textAlign: TextAlign.center,
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontSize: 16,
          fontFamily: 'Cairo',
          color: AppColors.darkGray,
        ),
        textAlign: TextAlign.center,
      ),
      actions: [
        if (showCancelButton)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onCancel != null) onCancel!();
            },
            child: Text(
              cancelText ?? 'إلغاء',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: AppColors.darkGray,
              ),
            ),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (onConfirm != null) onConfirm!();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppColors.brightRed : AppColors.lightBlue,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            confirmText ?? 'موافق',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

// Extension method for BuildContext to show alert dialog
extension AlertDialogContext on BuildContext {
  Future<void> showAlert({
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showDialog(
      context: this,
      builder: (context) => CustomAlertDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
  }

  Future<void> showDeleteConfirmation({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    return showAlert(
      title: title,
      message: message,
      confirmText: 'حذف',
      cancelText: 'إلغاء',
      onConfirm: onConfirm,
      isDestructive: true,
      icon: Icons.delete_forever,
    );
  }

  Future<void> showSuccess({
    required String title,
    required String message,
    VoidCallback? onConfirm,
  }) {
    return showAlert(
      title: title,
      message: message,
      confirmText: 'تم',
      onConfirm: onConfirm,
      icon: Icons.check_circle,
    );
  }

  Future<void> showError({
    required String title,
    required String message,
    VoidCallback? onConfirm,
  }) {
    return showAlert(
      title: title,
      message: message,
      confirmText: 'حسناً',
      onConfirm: onConfirm,
      icon: Icons.error,
      isDestructive: true,
    );
  }
} 