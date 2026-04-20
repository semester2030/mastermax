import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../cars/providers/car_provider.dart';
import '../../../../cars/models/car_model.dart';
import '../../../../auth/providers/auth_state.dart';
import '../dialogs/delete_confirmation_dialog.dart';
import 'vehicle_list_item.dart';

/// Widget لعرض تبويب المركبات
///
/// يعرض قائمة بجميع مركبات المستخدم مع إمكانية CRUD
/// يتبع الثيم الموحد للتطبيق
class VehiclesTab extends StatelessWidget {
  final NumberFormat numberFormat;

  const VehiclesTab({
    super.key,
    required this.numberFormat,
  });

  Future<void> _toggleCarStatus(BuildContext context, CarProvider provider, CarModel car) async {
    try {
      final updatedCar = car.copyWith(isActive: !car.isActive);
      await provider.updateCar(updatedCar);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              car.isActive ? 'تم إيقاف عرض السيارة' : 'تم تفعيل عرض السيارة',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CarProvider, AuthState>(
      builder: (context, carProvider, authState, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        
        if (carProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          );
        }

        final currentUserId = authState.user?.id;
        if (currentUserId == null) {
          return Center(
            child: Text(
              'يجب تسجيل الدخول',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        // عرض سيارات المستخدم الحالي فقط (sellerId == معرف المستخدم في Firebase / Firestore)
        final userCars = carProvider.cars.where((car) => car.sellerId == currentUserId).toList();
        final hasOtherSellersCars =
            carProvider.cars.isNotEmpty && userCars.isEmpty;

        if (userCars.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 64,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  hasOtherSellersCars
                      ? 'لا توجد مركبات مرتبطة بحسابك'
                      : 'لا توجد مركبات معروضة',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasOtherSellersCars) ...[
                  const SizedBox(height: 12),
                  Text(
                    'التطبيق يعرض هنا فقط السيارات التي حقل sellerId فيها يساوي معرّف حسابك (نفس uid في Firebase Auth / مستند users). '
                    'يوجد حالياً ${carProvider.cars.length} إعلاناً نشطاً في التطبيق لمعارض أخرى.\n\n'
                    'إن كنت أضفت سيارات ولا تظهر: افتح Firebase Console → Firestore → مجموعة cars وتأكد أن sellerId لكل سيارتك يساوي معرّف مستخدمك، أو أضف سيارة جديدة من هذا الحساب من داخل التطبيق (يُعبأ sellerId تلقائياً).',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, '/cars/add');
                    if (result == true && context.mounted) {
                      context.read<CarProvider>().loadCars();
                    }
                  },
                  icon: Icon(Icons.add, color: colorScheme.onPrimary),
                  label: Text(
                    'إضافة مركبة جديدة',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ],
            ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await carProvider.loadCars();
          },
          color: colorScheme.primary,
          backgroundColor: colorScheme.surface,
          strokeWidth: 3,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: userCars.length,
            itemBuilder: (context, index) {
              final car = userCars[index];
              return VehicleListItem(
                car: car,
                numberFormat: numberFormat,
                onView: () {
                  Navigator.pushNamed(
                    context,
                    '/car-details',
                    arguments: car.id,
                  );
                },
                onEdit: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/cars/edit',
                    arguments: car,
                  );
                  if (result == true && context.mounted) {
                    carProvider.loadCars();
                  }
                },
                onToggleStatus: () => _toggleCarStatus(context, carProvider, car),
                onDelete: () async {
                  final confirmed = await DeleteConfirmationDialog.show(
                    context,
                    provider: carProvider,
                    car: car,
                  );
                  if (confirmed) {
                    await carProvider.deleteCar(car.id);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}
