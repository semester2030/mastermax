import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// Dialog لإنشاء تقرير جديد
///
/// يعرض form لإنشاء تقرير بفترة زمنية محددة
/// يتبع الثيم الموحد للتطبيق
class CreateReportDialog extends StatefulWidget {
  final Function(DateTime startDate, DateTime endDate)? onReportCreated;

  const CreateReportDialog({
    super.key,
    this.onReportCreated,
  });

  static void show(
    BuildContext context, {
    Function(DateTime startDate, DateTime endDate)? onReportCreated,
  }) {
    showDialog(
      context: context,
      builder: (context) => CreateReportDialog(
        onReportCreated: onReportCreated,
      ),
    );
  }

  @override
  State<CreateReportDialog> createState() => _CreateReportDialogState();
}

class _CreateReportDialogState extends State<CreateReportDialog> {
  DateTime? startDate;
  DateTime? endDate;
  String? reportType;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(Icons.add_chart, color: AppColors.primary),
          SizedBox(width: 8),
          Text('إنشاء تقرير جديد'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'نوع التقرير',
                prefixIcon: Icon(Icons.description, color: AppColors.primary),
              ),
              items: const [
                DropdownMenuItem(value: 'sales', child: Text('تقرير المبيعات')),
                DropdownMenuItem(value: 'inventory', child: Text('تقرير المخزون')),
                DropdownMenuItem(value: 'customers', child: Text('تقرير العملاء')),
                DropdownMenuItem(value: 'performance', child: Text('تقرير الأداء')),
              ],
              onChanged: (value) {
                setState(() => reportType = value);
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: startDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.primary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) {
                  setState(() => startDate = date);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'من تاريخ',
                  prefixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
                ),
                child: Text(
                  startDate != null
                      ? '${startDate!.year}/${startDate!.month}/${startDate!.day}'
                      : 'اختر التاريخ',
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: endDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.primary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) {
                  setState(() => endDate = date);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'إلى تاريخ',
                  prefixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
                ),
                child: Text(
                  endDate != null
                      ? '${endDate!.year}/${endDate!.month}/${endDate!.day}'
                      : 'اختر التاريخ',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (startDate != null && endDate != null) {
              widget.onReportCreated?.call(startDate!, endDate!);
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('الرجاء اختيار التواريخ'),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('إنشاء'),
        ),
      ],
    );
  }
}
