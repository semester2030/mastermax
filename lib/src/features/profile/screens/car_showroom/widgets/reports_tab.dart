import 'package:flutter/material.dart';
import '../dialogs/create_report_dialog.dart';
import '../dialogs/generated_report_dialog.dart';

/// Widget لعرض تبويب التقارير
///
/// يعرض قائمة بالتقارير المتاحة
/// يتبع الثيم الموحد للتطبيق
class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'لا توجد تقارير متاحة حالياً',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'عند توفر بيانات المبيعات والمخزون سيتم إنشاء التقارير تلقائياً.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                CreateReportDialog.show(
                  context,
                  onReportCreated: (startDate, endDate) {
                    GeneratedReportDialog.show(
                      context,
                      startDate: startDate,
                      endDate: endDate,
                    );
                  },
                );
              },
              icon: const Icon(Icons.add_chart),
              label: const Text('إنشاء تقرير جديد'),
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
}
