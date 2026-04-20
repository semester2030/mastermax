import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../models/real_estate/rental_model.dart';

/// Widget لعرض إحصائيات عقود الإيجار
///
/// يعرض إحصائيات مختصرة عن عقود الإيجار
/// يتبع الثيم الموحد للتطبيق
class RentalStatsWidget extends StatelessWidget {
  final List<RentalModel> rentals;

  const RentalStatsWidget({
    super.key,
    required this.rentals,
  });

  @override
  Widget build(BuildContext context) {
    final activeRentals = rentals.where((r) => r.status == RentalStatus.active).toList();
    final expiringRentals = rentals.where((r) => r.isNearExpiry).toList();
    final totalMonthlyRevenue = activeRentals.fold<double>(0, (sum, r) => sum + r.monthlyRent);
    final currencyFormat = NumberFormat('#,###', 'ar');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إحصائيات الإيجارات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.home_work,
                  label: 'إجمالي العقود',
                  value: rentals.length.toString(),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  label: 'عقود نشطة',
                  value: activeRentals.length.toString(),
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.warning,
                  label: 'قريبة من الانتهاء',
                  value: expiringRentals.length.toString(),
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.attach_money,
                  label: 'إيرادات شهرية',
                  value: currencyFormat.format(totalMonthlyRevenue),
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    // ✅ الخلفية فاتحة جداً (alpha: 0.1)، لذلك نستخدم دائماً لون داكن للنص
    // ✅ استخدام AppColors.textPrimary مباشرة للوضوح الكامل
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), // ✅ خلفية فاتحة
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary, // ✅ لون داكن واضح دائماً
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary, // ✅ لون داكن ثانوي واضح
            ),
          ),
        ],
      ),
    );
  }
}
