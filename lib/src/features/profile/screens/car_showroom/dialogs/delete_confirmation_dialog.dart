import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../cars/providers/car_provider.dart';
import '../../../../cars/models/car_model.dart';

/// Dialog لتأكيد حذف السيارة
///
/// يعرض dialog لتأكيد عملية الحذف
/// يتبع الثيم الموحد للتطبيق
class DeleteConfirmationDialog extends StatelessWidget {
  final CarModel car;
  final CarProvider provider;
  final bool showDialogParam;

  const DeleteConfirmationDialog({
    super.key,
    required this.car,
    required this.provider,
    this.showDialogParam = true,
  });

  static Future<bool> show(
    BuildContext context, {
    required CarProvider provider,
    required CarModel car,
    bool showDialogParam = true,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        car: car,
        provider: provider,
        showDialogParam: showDialogParam,
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (!showDialogParam) {
      // للحذف السريع (Swipe to Delete)
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('تأكيد الحذف'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('هل أنت متأكد من حذف:'),
            const SizedBox(height: 8),
            Text(
              car.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'لا يمكن التراجع عن هذا الإجراء',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      );
    }

    // للحذف العادي (من PopupMenu)
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error),
          SizedBox(width: 8),
          Text('تأكيد الحذف'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('هل أنت متأكد من حذف:'),
          const SizedBox(height: 8),
          Text(
            car.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'لا يمكن التراجع عن هذا الإجراء',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await provider.deleteCar(car.id);
              if (context.mounted) {
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('تم حذف السيارة بنجاح'),
                    backgroundColor: AppColors.success,
                    action: SnackBarAction(
                      label: 'تراجع',
                      textColor: AppColors.white,
                      onPressed: () {
                        // TODO: إعادة السيارة (Undo)
                      },
                    ),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context, false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ: ${e.toString()}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          child: const Text('حذف'),
        ),
      ],
    );
  }
}
