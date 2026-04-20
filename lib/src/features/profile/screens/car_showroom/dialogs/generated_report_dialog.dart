import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../providers/car_showroom/sales_provider.dart';
import '../../../../auth/providers/auth_state.dart';
import '../../../services/car_showroom/export_service.dart';

/// Dialog لعرض التقرير المولد
///
/// يعرض التقرير المولد بناءً على الفترة الزمنية المحددة
/// يدعم تصدير Excel و PDF
/// يتبع الثيم الموحد للتطبيق
class GeneratedReportDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const GeneratedReportDialog({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  static void show(
    BuildContext context, {
    required DateTime startDate,
    required DateTime endDate,
  }) {
    showDialog(
      context: context,
      builder: (context) => GeneratedReportDialog(
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  @override
  State<GeneratedReportDialog> createState() => _GeneratedReportDialogState();
}

class _GeneratedReportDialogState extends State<GeneratedReportDialog> {
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd', 'ar');
  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ar');
  final ExportService _exportService = ExportService();
  bool _isExporting = false;
  List<dynamic> _reportSales = [];
  bool _isLoading = true;
  /// على الويب: الملف جاهز لكن التنزيل يحتاج نقرة صريحة (سياسات المتصفح).
  bool _webAwaitingDownload = false;
  String _webDownloadLabel = '';

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  @override
  void dispose() {
    _exportService.discardPendingWebExport();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    try {
      final salesProvider = context.read<SalesProvider>();
      final sales = await salesProvider.getSalesByDateRange(
        widget.startDate,
        widget.endDate,
      );
      setState(() {
        _reportSales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في تحميل البيانات: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final authState = context.read<AuthState>();
      final sellerName = authState.user?.name ?? 'غير معروف';

      final filePath = await _exportService.exportSalesToPDF(
        sales: _reportSales.cast(),
        sellerName: sellerName,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      if (!mounted) return;

      if (kIsWeb) {
        setState(() {
          _isExporting = false;
          _webAwaitingDownload = true;
          _webDownloadLabel = 'تحميل PDF';
        });
        return;
      }

      await _exportService.shareFile(filePath, context: context);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير التقرير بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في التصدير: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final authState = context.read<AuthState>();
      final sellerName = authState.user?.name ?? 'غير معروف';

      final filePath = await _exportService.exportSalesToExcel(
        sales: _reportSales.cast(),
        sellerName: sellerName,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      if (!mounted) return;

      if (kIsWeb) {
        setState(() {
          _isExporting = false;
          _webAwaitingDownload = true;
          _webDownloadLabel = 'تحميل Excel';
        });
        return;
      }

      await _exportService.shareFile(filePath, context: context);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير التقرير بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في التصدير: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = _reportSales.fold<double>(
      0,
      (sum, sale) => sum + (sale.salePrice as double),
    );
    final totalProfit = _reportSales.fold<double>(
      0,
      (sum, sale) => sum + ((sale.profit as double?) ?? 0),
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(Icons.description, color: AppColors.primary),
          SizedBox(width: 8),
          Text('التقرير المولد'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الفترة: من ${_dateFormat.format(widget.startDate)} إلى ${_dateFormat.format(widget.endDate)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // الإحصائيات
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildStatRow('عدد المبيعات:', '${_reportSales.length}'),
                        _buildStatRow('إجمالي المبيعات:', '${_numberFormat.format(totalSales)} ر.س'),
                        _buildStatRow('إجمالي الربح:', '${_numberFormat.format(totalProfit)} ر.س'),
                        if (_reportSales.isNotEmpty)
                          _buildStatRow(
                            'متوسط سعر البيع:',
                            '${_numberFormat.format(totalSales / _reportSales.length)} ر.س',
                          ),
                      ],
                    ),
                  ),
                  
                  if (_reportSales.isEmpty) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'لا توجد مبيعات في هذه الفترة',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                  if (_webAwaitingDownload) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: const Text(
                        'الملف جاهز. على المتصفح يجب الضغط يدويًا على «تحميل» لبدء التنزيل.',
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.35),
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        if (_webAwaitingDownload) ...[
          TextButton(
            onPressed: () {
              _exportService.discardPendingWebExport();
              setState(() {
                _webAwaitingDownload = false;
                _webDownloadLabel = '';
              });
            },
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () {
              _exportService.downloadPendingWebExport();
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم بدء تنزيل الملف'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            icon: const Icon(Icons.download),
            label: Text(_webDownloadLabel.isEmpty ? 'تحميل الملف' : _webDownloadLabel),
          ),
        ] else ...[
          TextButton(
            onPressed: _isExporting ? null : () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            onPressed: _isExporting ? null : _exportToExcel,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_chart),
            label: const Text('Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isExporting ? null : _exportToPDF,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: const Text('PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
