import 'package:flutter/material.dart';
import '../models/property_models.dart';
import '../../../../../core/theme/app_colors.dart';

class SalesSummaryWidget extends StatelessWidget {
  final List<Sale> sales;

  const SalesSummaryWidget({
    required this.sales, super.key,
  });

  double get totalSales => sales.fold<double>(0, (sum, sale) => sum + sale.amount);
  double get totalProfit => sales.fold<double>(0, (sum, sale) => sum + (sale.amount - sale.propertyDetails.purchasePrice));
  double get averageSaleTime => sales.isEmpty ? 0 : sales.fold<int>(0, (sum, sale) => sum + sale.daysToSell) / sales.length;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص المبيعات',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(context, 'إجمالي المبيعات', '$totalSales ر.س'),
            _buildSummaryRow(context, 'إجمالي الأرباح', '$totalProfit ر.س'),
            _buildSummaryRow(context, 'متوسط وقت البيع', '${averageSaleTime.toStringAsFixed(1)} يوم'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 