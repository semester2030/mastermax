import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import '../../models/car_showroom/sale_model.dart';
import '../base_export_service.dart';
import '../base_export_service_stub.dart'
    if (dart.library.html) '../base_export_service_web.dart' as export_web;

/// Service لتصدير البيانات إلى Excel و PDF
///
/// يوفر وظائف تصدير التقارير للمركبات (موبايل + ويب تنزيل مباشر)
class ExportService extends BaseExportService {
  Uint8List? _lastFileBytes;
  String? _lastFileName;

  /// على الويب: التنزيل بعد نقرة المستخدم (المتصفحات تمنع غالبًا التنزيل البرمجي بعد await طويل).
  void downloadPendingWebExport() {
    if (!kIsWeb) return;
    if (_lastFileBytes == null || _lastFileName == null) return;
    export_web.downloadFileForWeb(_lastFileBytes!, _lastFileName!);
    _lastFileBytes = null;
    _lastFileName = null;
  }

  /// عند إغلاق الحوار دون تحميل — لتفريغ الذاكرة.
  void discardPendingWebExport() {
    _lastFileBytes = null;
    _lastFileName = null;
  }

  @override
  Future<void> shareFile(
    String filePath, {
    String? text,
    BuildContext? context,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    if (kIsWeb && _lastFileBytes != null && _lastFileName != null) {
      await super.shareFile(
        filePath,
        text: text,
        context: context,
        fileBytes: _lastFileBytes,
        fileName: _lastFileName,
      );
      _lastFileBytes = null;
      _lastFileName = null;
    } else {
      await super.shareFile(
        filePath,
        text: text,
        context: context,
        fileBytes: fileBytes,
        fileName: fileName,
      );
    }
  }

  /// تصدير المبيعات إلى Excel
  Future<String> exportSalesToExcel({
    required List<SaleModel> sales,
    required String sellerName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['المبيعات'];

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          TextCellValue('تقرير المبيعات');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
          TextCellValue('البائع: $sellerName');

      if (startDate != null && endDate != null) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value =
            TextCellValue(
                'الفترة: من ${dateFormat.format(startDate)} إلى ${dateFormat.format(endDate)}');
      }

      final headers = ['#', 'تاريخ البيع', 'السيارة', 'العميل', 'سعر البيع', 'الربح', 'طريقة الدفع'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4)).value =
            TextCellValue(headers[i]);
      }

      for (int i = 0; i < sales.length; i++) {
        final sale = sales[i];
        final rowIndex = i + 5;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
            IntCellValue(i + 1);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
            TextCellValue(dateFormat.format(sale.saleDate));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
            TextCellValue(sale.carTitle);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
            TextCellValue(sale.customerName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value =
            TextCellValue(numberFormat.format(sale.salePrice));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value =
            TextCellValue(sale.profit != null ? numberFormat.format(sale.profit!) : '-');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value =
            TextCellValue(sale.paymentMethod ?? '-');
      }

      final totalRow = sales.length + 6;
      final totalSalesAmount = sales.fold<double>(0, (sum, sale) => sum + sale.salePrice);
      final totalProfitAmount = sales.fold<double>(0, (sum, sale) => sum + (sale.profit ?? 0));

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRow)).value =
          TextCellValue('الإجمالي:');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow)).value =
          TextCellValue(numberFormat.format(totalSalesAmount));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRow)).value =
          TextCellValue(numberFormat.format(totalProfitAmount));

      final fileBytesList = excel.save();
      if (fileBytesList == null) {
        throw 'فشل في إنشاء ملف Excel';
      }

      final fileBytes = Uint8List.fromList(fileBytesList);
      final fileName = 'sales_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      if (kIsWeb) {
        _lastFileBytes = fileBytes;
        _lastFileName = fileName;
        return fileName;
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      await File(filePath).writeAsBytes(fileBytes);
      return filePath;
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
      rethrow;
    }
  }

  /// تصدير المبيعات إلى PDF
  Future<String> exportSalesToPDF({
    required List<SaleModel> sales,
    required String sellerName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final pdf = pw.Document();

      final totalSalesAmount = sales.fold<double>(0, (sum, sale) => sum + sale.salePrice);
      final totalProfitAmount = sales.fold<double>(0, (sum, sale) => sum + (sale.profit ?? 0));
      final averageSale = sales.isNotEmpty ? totalSalesAmount / sales.length : 0.0;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'تقرير المبيعات',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'البائع: $sellerName',
              style: const pw.TextStyle(fontSize: 14),
            ),
            if (startDate != null && endDate != null)
              pw.Text(
                'الفترة: من ${dateFormat.format(startDate)} إلى ${dateFormat.format(endDate)}',
                style: const pw.TextStyle(fontSize: 14),
              ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'الإحصائيات',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  buildStatRow('عدد المبيعات:', '${sales.length}'),
                  buildStatRow('إجمالي المبيعات:', '${numberFormat.format(totalSalesAmount)} ر.س'),
                  buildStatRow('إجمالي الربح:', '${numberFormat.format(totalProfitAmount)} ر.س'),
                  buildStatRow('متوسط سعر البيع:', '${numberFormat.format(averageSale)} ر.س'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  children: [
                    buildTableCell('طريقة الدفع', isHeader: true),
                    buildTableCell('الربح', isHeader: true),
                    buildTableCell('سعر البيع', isHeader: true),
                    buildTableCell('العميل', isHeader: true),
                    buildTableCell('السيارة', isHeader: true),
                    buildTableCell('تاريخ البيع', isHeader: true),
                    buildTableCell('#', isHeader: true),
                  ],
                ),
                ...sales.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sale = entry.value;
                  return pw.TableRow(
                    children: [
                      buildTableCell(sale.paymentMethod ?? '-'),
                      buildTableCell(
                          sale.profit != null ? numberFormat.format(sale.profit!) : '-'),
                      buildTableCell(numberFormat.format(sale.salePrice)),
                      buildTableCell(sale.customerName),
                      buildTableCell(sale.carTitle),
                      buildTableCell(dateFormat.format(sale.saleDate)),
                      buildTableCell('${index + 1}'),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = 'sales_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        _lastFileBytes = pdfBytes;
        _lastFileName = fileName;
        return fileName;
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      await File(filePath).writeAsBytes(pdfBytes);
      return filePath;
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
      rethrow;
    }
  }
}
