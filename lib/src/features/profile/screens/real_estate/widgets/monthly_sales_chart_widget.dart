import 'package:flutter/material.dart';
import '../models/property_models.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/color_utils.dart';

class MonthlySalesChartWidget extends StatelessWidget {
  final List<Sale> sales;

  const MonthlySalesChartWidget({
    required this.sales, super.key,
  });

  Map<String, double> get monthlySales {
    final Map<String, double> result = {};
    for (var sale in sales) {
      final monthKey = '${sale.date.year}-${sale.date.month}';
      result[monthKey] = (result[monthKey] ?? 0) + sale.amount;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المبيعات الشهرية',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (monthlySales.isEmpty) {
      return const Center(
        child: Text('لا توجد بيانات للعرض'),
      );
    }

    final maxValue = monthlySales.values.reduce((a, b) => a > b ? a : b);
    const barWidth = 40.0;
    const spacing = 20.0;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: monthlySales.length,
      separatorBuilder: (context, index) => const SizedBox(width: spacing),
      itemBuilder: (context, index) {
        final entry = monthlySales.entries.elementAt(index);
        final height = (entry.value / maxValue) * 150;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: barWidth,
              height: height,
              decoration: BoxDecoration(
                color: ColorUtils.withOpacity(AppColors.chartBlue, 0.7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.key,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.value.toStringAsFixed(0)} ر.س',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }
} 