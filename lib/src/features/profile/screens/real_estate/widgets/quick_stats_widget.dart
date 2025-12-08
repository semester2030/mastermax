import 'package:flutter/material.dart';
import '../models/property_models.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/color_utils.dart';

class QuickStatsWidget extends StatelessWidget {
  final List<Sale> sales;

  const QuickStatsWidget({
    required this.sales, super.key,
  });

  double get totalSales => sales.fold<double>(0, (sum, sale) => sum + sale.amount);
  double get totalProfit => sales.fold<double>(0, (sum, sale) => sum + (sale.amount - sale.propertyDetails.purchasePrice));
  double get averageSaleTime => sales.isEmpty ? 0 : sales.fold<int>(0, (sum, sale) => sum + sale.daysToSell) / sales.length;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إحصائيات سريعة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'إجمالي المبيعات',
                    '$totalSales ر.س',
                    Icons.monetization_on,
                    AppColors.chartBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'إجمالي الأرباح',
                    '$totalProfit ر.س',
                    Icons.trending_up,
                    AppColors.chartGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'متوسط وقت البيع',
                    '${averageSaleTime.toStringAsFixed(1)} يوم',
                    Icons.timer,
                    AppColors.chartOrange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'عدد المبيعات',
                    '${sales.length}',
                    Icons.show_chart,
                    AppColors.chartPurple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorUtils.withOpacity(color, 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 