import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/color_utils.dart';
import '../../../../cars/providers/car_provider.dart';
import '../../../../cars/models/car_model.dart';
import '../../../../auth/providers/auth_state.dart';
import 'stat_card.dart';

/// Widget لعرض إحصائيات Dashboard
///
/// يعرض إحصائيات سريعة عن المركبات (الإجمالي، النشطة، المحجوزة، القيمة الإجمالية)
/// يتبع الثيم الموحد للتطبيق
class DashboardStats extends StatelessWidget {
  final NumberFormat numberFormat;

  const DashboardStats({
    super.key,
    required this.numberFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<CarProvider, AuthState>(
      builder: (context, carProvider, authState, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final uid = authState.user?.id;
        // نفس منطق تبويب المركبات: سيارات البائع الحالي فقط
        final cars = uid == null
            ? <CarModel>[]
            : carProvider.cars.where((car) => car.sellerId == uid).toList();

        // حساب الإحصائيات من البيانات الحقيقية
        final totalVehicles = cars.length;
        final activeVehicles = cars.where((car) => car.isActive).length;
        const reservedVehicles = 0; // TODO: إضافة منطق الحجوزات لاحقاً
        final totalRevenue = cars.fold<double>(0, (sum, car) => sum + car.price);
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      // primaryContainer غير مُعرّف في الثيم → يُشتق قريباً من primary فيُخفي الأيقونة
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ColorUtils.withOpacity(AppColors.primary, 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.dashboard_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'لوحة المعلومات',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  StatCard(
                    title: 'إجمالي المركبات',
                    value: totalVehicles.toString(),
                    icon: Icons.directions_car_filled,
                    color: colorScheme.primary,
                    tooltip: 'عدد سياراتك (sellerId = حسابك) ضمن الإعلانات النشطة',
                    numberFormat: numberFormat,
                  ),
                  StatCard(
                    title: 'المركبات النشطة',
                    value: activeVehicles.toString(),
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    tooltip: 'سياراتك المعروضة حالياً (isActive)',
                    numberFormat: numberFormat,
                  ),
                  StatCard(
                    title: 'تحت الحجز',
                    value: reservedVehicles.toString(),
                    icon: Icons.pending_actions_outlined,
                    color: colorScheme.primary,
                    tooltip: 'عدد الحجوزات النشطة',
                    numberFormat: numberFormat,
                  ),
                  StatCard(
                    title: 'إجمالي القيمة',
                    value: '${numberFormat.format(totalRevenue)} ر.س',
                    icon: Icons.account_balance_wallet_outlined,
                    color: colorScheme.primary,
                    tooltip: 'مجموع أسعار إعلاناتك (مركباتك فقط)',
                    numberFormat: numberFormat,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
