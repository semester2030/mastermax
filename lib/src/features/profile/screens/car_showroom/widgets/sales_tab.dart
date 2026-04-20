import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/color_utils.dart';
import '../../../providers/car_showroom/sales_provider.dart';
import '../../../models/car_showroom/sale_model.dart';
import '../dialogs/add_sale_dialog.dart';

/// Widget لعرض تبويب المبيعات
///
/// يعرض قائمة بالمبيعات من Firestore مع إمكانية CRUD
/// يتبع الثيم الموحد للتطبيق
class SalesTab extends StatelessWidget {
  const SalesTab({super.key});

  static final NumberFormat _numberFormat = NumberFormat('#,##0', 'ar');
  static final DateFormat _dateFormat = DateFormat('yyyy/MM/dd', 'ar');

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesProvider>(
      builder: (context, provider, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        if (provider.isLoading && provider.sales.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          );
        }

        if (provider.sales.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.point_of_sale_outlined, size: 64, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد بيانات مبيعات بعد',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'عند تسجيل عمليات البيع ستظهر هنا.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => AddSaleDialog.show(context),
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('تسجيل عملية بيع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadSales(),
          color: colorScheme.primary,
          backgroundColor: colorScheme.surface,
          strokeWidth: 3,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.sales.length,
            itemBuilder: (context, index) {
              final sale = provider.sales[index];
              return _buildSaleCard(context, sale, provider, colorScheme, textTheme);
            },
          ),
        );
      },
    );
  }

  Widget _buildSaleCard(
    BuildContext context,
    SaleModel sale,
    SalesProvider provider,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
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
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            // TODO: عرض تفاصيل عملية البيع
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: ColorUtils.withOpacity(AppColors.primary, 0.08),
          highlightColor: ColorUtils.withOpacity(AppColors.primary, 0.06),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // أيقونة البيع
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        color: AppColors.success,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // معلومات البيع
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.carTitle,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'العميل: ${sale.customerName}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // السعر
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_numberFormat.format(sale.salePrice)} ر.س',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        if (sale.profit != null)
                          Text(
                            'ربح: ${_numberFormat.format(sale.profit!)} ر.س',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // معلومات إضافية
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _dateFormat.format(sale.saleDate),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (sale.paymentMethod != null) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.payment,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sale.paymentMethod!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
