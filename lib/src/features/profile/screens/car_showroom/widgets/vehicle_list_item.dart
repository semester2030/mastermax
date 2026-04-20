import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/color_utils.dart';
import '../../../../cars/models/car_model.dart';
import '../../../../cars/providers/car_provider.dart';
import '../dialogs/delete_confirmation_dialog.dart';

/// Widget لعرض عنصر سيارة في القائمة
///
/// يعرض معلومات السيارة مع إمكانية الحذف والتعديل
/// يتبع الثيم الموحد للتطبيق
class VehicleListItem extends StatelessWidget {
  final CarModel car;
  final NumberFormat numberFormat;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final Future<void> Function() onToggleStatus;
  final Future<void> Function() onDelete;

  const VehicleListItem({
    super.key,
    required this.car,
    required this.numberFormat,
    required this.onView,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final itemColorScheme = Theme.of(context).colorScheme;
    final itemTextTheme = Theme.of(context).textTheme;

    return Dismissible(
      key: Key(car.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.white,
          size: 32,
        ),
      ),
      confirmDismiss: (direction) async {
        final provider = context.read<CarProvider>();
        return await DeleteConfirmationDialog.show(
          context,
          provider: provider,
          car: car,
          showDialogParam: false,
        );
      },
      onDismissed: (direction) async {
        await onDelete();
      },
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: ColorUtils.withOpacity(AppColors.primary, 0.22),
            width: 1,
          ),
        ),
        child: Material(
          color: itemColorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onView,
            borderRadius: BorderRadius.circular(16),
            splashColor: ColorUtils.withOpacity(AppColors.primary, 0.08),
            highlightColor: ColorUtils.withOpacity(AppColors.primary, 0.06),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ColorUtils.withOpacity(AppColors.primary, 0.22),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.withOpacity(AppColors.primary, 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: car.mainImage.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          car.mainImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.directions_car_filled,
                              color: AppColors.primary,
                              size: 36,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_car_filled,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
              ),
              title: Text(
                car.title,
                style: itemTextTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: itemColorScheme.onSurface,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: ColorUtils.withOpacity(AppColors.primary, 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.attach_money,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${numberFormat.format(car.price)} ر.س',
                        style: itemTextTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: itemColorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                /// خلفية فاتحة بدل لون الحاوية البنفسجي الغامق الافتراضي لقائمة Material 3.
                color: AppColors.white,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.black26,
                elevation: 8,
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    /// فاتح مثل عناصر القائمة — بدل primaryContainer البنفسجي الغامق.
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.more_vert,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) => [
                  _PopupMenuItem(
                    title: 'عرض التفاصيل',
                    icon: Icons.visibility_outlined,
                    value: 'view',
                  ),
                  _PopupMenuItem(
                    title: 'تعديل',
                    icon: Icons.edit_outlined,
                    value: 'edit',
                  ),
                  _PopupMenuItem(
                    title: car.isActive ? 'إيقاف العرض' : 'تفعيل العرض',
                    icon: car.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    value: 'toggle',
                  ),
                  _PopupMenuItem(
                    title: 'حذف',
                    icon: Icons.delete_outline,
                    value: 'delete',
                    isDestructive: true,
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'view') {
                    onView();
                  } else if (value == 'edit') {
                    onEdit();
                  } else if (value == 'toggle') {
                    await onToggleStatus();
                  } else if (value == 'delete') {
                    await onDelete();
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupMenuItem extends PopupMenuItem<String> {
  final String title;
  final IconData icon;
  final bool isDestructive;

  _PopupMenuItem({
    required this.title,
    required this.icon,
    required super.value,
    this.isDestructive = false,
  }) : super(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.error.withValues(alpha: 0.2)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? AppColors.error : AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDestructive ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
}
