import 'package:flutter/material.dart';
import '../../src/core/theme/app_colors.dart';

/// جدول بيانات بسيط للوحة الإدارة
class AdminDataTable extends StatelessWidget {
  final List<String> columns;
  final List<DataRow> rows;
  final bool isLoading;

  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.primaryLight),
          columns: columns
              .map((c) => DataColumn(
                    label: Text(
                      c,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ))
              .toList(),
          rows: rows,
        ),
      ),
    );
  }
}
