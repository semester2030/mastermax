import 'package:flutter/material.dart';
import '../models/property_models.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/color_utils.dart';
import 'package:intl/intl.dart' as intl;

class RecentTransactionsWidget extends StatelessWidget {
  final TabController tabController;
  final List<Sale> sales;

  const RecentTransactionsWidget({
    required this.tabController, required this.sales, super.key,
  });

  @override
  Widget build(BuildContext context) {
    final recentSales = sales.take(5).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'آخر المعاملات',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => tabController.animateTo(1),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (recentSales.isEmpty)
              const Center(
                child: Text('لا توجد معاملات حديثة'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentSales.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final sale = recentSales[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ColorUtils.withOpacity(AppColors.primary, 0.1),
                      child: Icon(
                        _getIconForPropertyType(sale.propertyDetails.type),
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(sale.propertyDetails.title),
                    subtitle: Text(
                      intl.DateFormat.yMMMd().format(sale.date),
                    ),
                    trailing: Text(
                      '${sale.amount} ر.س',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForPropertyType(PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return Icons.apartment;
      case PropertyType.villa:
        return Icons.home;
      case PropertyType.land:
        return Icons.landscape;
      case PropertyType.commercial:
        return Icons.business;
    }
  }
} 