import 'package:flutter/material.dart';
import '../models/property_models.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/color_utils.dart';

class ReportsTabWidget extends StatelessWidget {
  final List<Sale> sales;

  const ReportsTabWidget({
    required this.sales, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildReportCard(
          'تقرير المبيعات',
          'تحليل شامل لأداء المبيعات',
          Icons.bar_chart,
          AppColors.primary,
          () {
            // TODO: Generate and show sales report
          },
        ),
        const SizedBox(height: 16),
        _buildReportCard(
          'تقرير الأرباح',
          'تحليل الأرباح والخسائر',
          Icons.trending_up,
          AppColors.success,
          () {
            // TODO: Generate and show profits report
          },
        ),
        const SizedBox(height: 16),
        _buildReportCard(
          'تقرير المخزون',
          'تحليل حالة المخزون العقاري',
          Icons.inventory,
          AppColors.primaryDark,
          () {
            // TODO: Generate and show inventory report
          },
        ),
        const SizedBox(height: 16),
        _buildReportCard(
          'تقرير الأداء',
          'تحليل مؤشرات الأداء الرئيسية',
          Icons.analytics,
          AppColors.primary,
          () {
            // TODO: Generate and show performance report
          },
        ),
      ],
    );
  }

  Widget _buildReportCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ColorUtils.withOpacity(color, 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.download),
          onPressed: onTap,
        ),
      ),
    );
  }
} 