import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import '../../models/real_estate/rental_model.dart';
import '../../screens/real_estate/models/property_models.dart';
import '../base_export_service.dart';

/// Service لتصدير بيانات العقارات إلى Excel و PDF
///
/// يوفر وظائف تصدير تقارير المبيعات والإيجارات
class RealEstateExportService extends BaseExportService {
  // ✅ متغيرات لحفظ bytes للويب
  Uint8List? _lastFileBytes;
  String? _lastFileName;
  
  /// ✅ مشاركة الملف (override للويب)
  @override
  Future<void> shareFile(String filePath, {String? text, BuildContext? context, Uint8List? fileBytes, String? fileName}) async {
    if (kIsWeb && _lastFileBytes != null && _lastFileName != null) {
      // ✅ للويب: استخدام bytes المحفوظة
      await super.shareFile(
        filePath,
        text: text,
        context: context,
        fileBytes: _lastFileBytes,
        fileName: _lastFileName,
      );
      // ✅ مسح المتغيرات بعد الاستخدام
      _lastFileBytes = null;
      _lastFileName = null;
    } else {
      // ✅ للموبايل: استخدام الطريقة العادية
      await super.shareFile(filePath, text: text, context: context, fileBytes: fileBytes, fileName: fileName);
    }
  }

  /// تصدير مبيعات العقارات إلى Excel
  Future<String> exportSalesToExcel({
    required List<Sale> sales,
    required String companyName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['مبيعات العقارات'];

      // العنوان
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 
          TextCellValue('تقرير مبيعات العقارات');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = 
          TextCellValue('الشركة: $companyName');
      
      if (startDate != null && endDate != null) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = 
            TextCellValue('الفترة: من ${dateFormat.format(startDate)} إلى ${dateFormat.format(endDate)}');
      }

      // رؤوس الأعمدة
      final headers = ['#', 'تاريخ البيع', 'العقار', 'النوع', 'الموقع', 'سعر البيع', 'سعر الشراء', 'الربح', 'طريقة الدفع', 'أيام البيع'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4)).value = 
            TextCellValue(headers[i]);
      }

      // البيانات
      for (int i = 0; i < sales.length; i++) {
        final sale = sales[i];
        final rowIndex = i + 5;
        
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 
            IntCellValue(i + 1);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = 
            TextCellValue(dateFormat.format(sale.date));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = 
            TextCellValue(sale.propertyDetails.title);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = 
            TextCellValue(sale.propertyDetails.type.arabicName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = 
            TextCellValue(sale.propertyDetails.location);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = 
            TextCellValue(numberFormat.format(sale.amount));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = 
            TextCellValue(numberFormat.format(sale.propertyDetails.purchasePrice));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = 
            TextCellValue(numberFormat.format(sale.profit));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = 
            TextCellValue(sale.paymentMethod.arabicName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = 
            IntCellValue(sale.daysToSell);
      }

      // الإجمالي
      final totalRow = sales.length + 6;
      final totalSales = sales.fold<double>(0, (sum, sale) => sum + sale.amount);
      final totalProfit = sales.fold<double>(0, (sum, sale) => sum + sale.profit);
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow)).value = 
          TextCellValue('الإجمالي:');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRow)).value = 
          TextCellValue(numberFormat.format(totalSales));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: totalRow)).value = 
          TextCellValue(numberFormat.format(totalProfit));

      // حفظ الملف
      final fileBytesList = excel.save();
      if (fileBytesList == null) {
        throw 'فشل في إنشاء ملف Excel';
      }
      
      // ✅ تحويل List<int> إلى Uint8List
      final fileBytes = Uint8List.fromList(fileBytesList);
      final fileName = 'real_estate_sales_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      if (kIsWeb) {
        // ✅ للويب: حفظ bytes للاستخدام في shareFile
        _lastFileBytes = fileBytes;
        _lastFileName = fileName;
        return fileName; // نعيد اسم الملف فقط
      } else {
        // ✅ للموبايل: استخدام path_provider
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        return filePath;
      }
    } catch (e) {
      debugPrint('Error exporting sales to Excel: $e');
      rethrow;
    }
  }

  /// تصدير مبيعات العقارات إلى PDF
  Future<String> exportSalesToPDF({
    required List<Sale> sales,
    required String companyName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final pdf = pw.Document();

      // حساب الإحصائيات
      final totalSales = sales.fold<double>(0, (sum, sale) => sum + sale.amount);
      final totalProfit = sales.fold<double>(0, (sum, sale) => sum + sale.profit);
      final averageSale = sales.isNotEmpty ? totalSales / sales.length : 0;
      final averageProfit = sales.isNotEmpty ? totalProfit / sales.length : 0;
      final averageDays = sales.isNotEmpty 
          ? sales.fold<int>(0, (sum, sale) => sum + sale.daysToSell) / sales.length 
          : 0;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // العنوان
            pw.Header(
              level: 0,
              child: pw.Text(
                'تقرير مبيعات العقارات',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            
            // معلومات التقرير
            pw.Text(
              'الشركة: $companyName',
              style: const pw.TextStyle(fontSize: 14),
            ),
            if (startDate != null && endDate != null)
              pw.Text(
                'الفترة: من ${dateFormat.format(startDate)} إلى ${dateFormat.format(endDate)}',
                style: const pw.TextStyle(fontSize: 14),
              ),
            pw.SizedBox(height: 20),

            // الإحصائيات
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
                  buildStatRow('إجمالي المبيعات:', '${numberFormat.format(totalSales)} ر.س'),
                  buildStatRow('إجمالي الربح:', '${numberFormat.format(totalProfit)} ر.س'),
                  buildStatRow('متوسط سعر البيع:', '${numberFormat.format(averageSale)} ر.س'),
                  buildStatRow('متوسط الربح:', '${numberFormat.format(averageProfit)} ر.س'),
                  buildStatRow('متوسط أيام البيع:', '${averageDays.toStringAsFixed(1)} يوم'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // جدول المبيعات
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // رؤوس الأعمدة
                pw.TableRow(
                  children: [
                    buildTableCell('أيام البيع', isHeader: true),
                    buildTableCell('طريقة الدفع', isHeader: true),
                    buildTableCell('الربح', isHeader: true),
                    buildTableCell('سعر البيع', isHeader: true),
                    buildTableCell('الموقع', isHeader: true),
                    buildTableCell('النوع', isHeader: true),
                    buildTableCell('العقار', isHeader: true),
                    buildTableCell('تاريخ البيع', isHeader: true),
                    buildTableCell('#', isHeader: true),
                  ],
                ),
                // البيانات
                ...sales.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sale = entry.value;
                  return pw.TableRow(
                    children: [
                      buildTableCell('${sale.daysToSell}'),
                      buildTableCell(sale.paymentMethod.arabicName),
                      buildTableCell(numberFormat.format(sale.profit)),
                      buildTableCell(numberFormat.format(sale.amount)),
                      buildTableCell(sale.propertyDetails.location),
                      buildTableCell(sale.propertyDetails.type.arabicName),
                      buildTableCell(sale.propertyDetails.title),
                      buildTableCell(dateFormat.format(sale.date)),
                      buildTableCell('${index + 1}'),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      );

      // حفظ الملف
      final pdfBytes = await pdf.save();
      final fileName = 'real_estate_sales_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      if (kIsWeb) {
        // ✅ للويب: حفظ bytes للاستخدام في shareFile
        _lastFileBytes = pdfBytes;
        _lastFileName = fileName;
        return fileName; // نعيد اسم الملف فقط
      } else {
        // ✅ للموبايل: استخدام path_provider
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);
        return filePath;
      }
    } catch (e) {
      debugPrint('Error exporting sales to PDF: $e');
      rethrow;
    }
  }

  /// تصدير عقود الإيجار إلى Excel
  Future<String> exportRentalsToExcel({
    required List<RentalModel> rentals,
    required String companyName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['عقود الإيجار'];

      // العنوان
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 
          TextCellValue('تقرير عقود الإيجار');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = 
          TextCellValue('الشركة: $companyName');
      
      if (startDate != null && endDate != null) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = 
            TextCellValue('الفترة: من ${dateFormat.format(startDate)} إلى ${dateFormat.format(endDate)}');
      }

      // رؤوس الأعمدة
      final headers = ['#', 'رقم العقد', 'العقار', 'المستأجر', 'نوع الإيجار', 'الإيجار الشهري', 'تاريخ البداية', 'تاريخ النهاية', 'الضمان', 'الحالة'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4)).value = 
            TextCellValue(headers[i]);
      }

      // البيانات
      for (int i = 0; i < rentals.length; i++) {
        final rental = rentals[i];
        final rowIndex = i + 5;
        
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 
            IntCellValue(i + 1);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = 
            TextCellValue(rental.contractNumber ?? '-');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = 
            TextCellValue(rental.propertyTitle);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = 
            TextCellValue(rental.customerName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = 
            TextCellValue(rental.rentalType.arabicName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = 
            TextCellValue(numberFormat.format(rental.monthlyRent));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = 
            TextCellValue(dateFormat.format(rental.startDate));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = 
            TextCellValue(dateFormat.format(rental.endDate));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = 
            TextCellValue(numberFormat.format(rental.deposit));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = 
            TextCellValue(rental.status.arabicName);
      }

      // الإجمالي
      final totalRow = rentals.length + 6;
      final totalMonthlyRent = rentals.fold<double>(0, (sum, rental) => sum + rental.monthlyRent);
      final totalDeposit = rentals.fold<double>(0, (sum, rental) => sum + rental.deposit);
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow)).value = 
          TextCellValue('الإجمالي:');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRow)).value = 
          TextCellValue(numberFormat.format(totalMonthlyRent));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: totalRow)).value = 
          TextCellValue(numberFormat.format(totalDeposit));

      // حفظ الملف
      final fileBytesList = excel.save();
      if (fileBytesList == null) {
        throw 'فشل في إنشاء ملف Excel';
      }
      
      // ✅ تحويل List<int> إلى Uint8List
      final fileBytes = Uint8List.fromList(fileBytesList);
      final fileName = 'rentals_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      if (kIsWeb) {
        // ✅ للويب: حفظ bytes للاستخدام في shareFile
        _lastFileBytes = fileBytes;
        _lastFileName = fileName;
        return fileName; // نعيد اسم الملف فقط
      } else {
        // ✅ للموبايل: استخدام path_provider
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        return filePath;
      }
    } catch (e) {
      debugPrint('Error exporting rentals to Excel: $e');
      rethrow;
    }
  }

  /// تصدير عقود الإيجار إلى PDF
  Future<String> exportRentalsToPDF({
    required List<RentalModel> rentals,
    required String companyName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final pdf = pw.Document();

      // حساب الإحصائيات
      final totalMonthlyRent = rentals.fold<double>(0, (sum, rental) => sum + rental.monthlyRent);
      final totalDeposit = rentals.fold<double>(0, (sum, rental) => sum + rental.deposit);
      final averageMonthlyRent = rentals.isNotEmpty ? totalMonthlyRent / rentals.length : 0;
      final activeRentals = rentals.where((r) => r.status == RentalStatus.active).length;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // العنوان
            pw.Header(
              level: 0,
              child: pw.Text(
                'تقرير عقود الإيجار',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            
            // معلومات التقرير
            pw.Text(
              'الشركة: $companyName',
              style: const pw.TextStyle(fontSize: 14),
            ),
            if (startDate != null && endDate != null)
              pw.Text(
                'الفترة: من ${dateFormat.format(startDate)} إلى ${dateFormat.format(endDate)}',
                style: const pw.TextStyle(fontSize: 14),
              ),
            pw.SizedBox(height: 20),

            // الإحصائيات
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
                  buildStatRow('عدد العقود:', '${rentals.length}'),
                  buildStatRow('العقود النشطة:', '$activeRentals'),
                  buildStatRow('إجمالي الإيجار الشهري:', '${numberFormat.format(totalMonthlyRent)} ر.س'),
                  buildStatRow('إجمالي الضمانات:', '${numberFormat.format(totalDeposit)} ر.س'),
                  buildStatRow('متوسط الإيجار الشهري:', '${numberFormat.format(averageMonthlyRent)} ر.س'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // جدول العقود
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // رؤوس الأعمدة
                pw.TableRow(
                  children: [
                    buildTableCell('الحالة', isHeader: true),
                    buildTableCell('الضمان', isHeader: true),
                    buildTableCell('تاريخ النهاية', isHeader: true),
                    buildTableCell('تاريخ البداية', isHeader: true),
                    buildTableCell('الإيجار الشهري', isHeader: true),
                    buildTableCell('نوع الإيجار', isHeader: true),
                    buildTableCell('المستأجر', isHeader: true),
                    buildTableCell('العقار', isHeader: true),
                    buildTableCell('#', isHeader: true),
                  ],
                ),
                // البيانات
                ...rentals.asMap().entries.map((entry) {
                  final index = entry.key;
                  final rental = entry.value;
                  return pw.TableRow(
                    children: [
                      buildTableCell(rental.status.arabicName),
                      buildTableCell(numberFormat.format(rental.deposit)),
                      buildTableCell(dateFormat.format(rental.endDate)),
                      buildTableCell(dateFormat.format(rental.startDate)),
                      buildTableCell(numberFormat.format(rental.monthlyRent)),
                      buildTableCell(rental.rentalType.arabicName),
                      buildTableCell(rental.customerName),
                      buildTableCell(rental.propertyTitle),
                      buildTableCell('${index + 1}'),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      );

      // حفظ الملف
      final pdfBytes = await pdf.save();
      final fileName = 'rentals_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      if (kIsWeb) {
        // ✅ للويب: حفظ bytes للاستخدام في shareFile
        _lastFileBytes = pdfBytes;
        _lastFileName = fileName;
        return fileName; // نعيد اسم الملف فقط
      } else {
        // ✅ للموبايل: استخدام path_provider
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);
        return filePath;
      }
    } catch (e) {
      debugPrint('Error exporting rentals to PDF: $e');
      rethrow;
    }
  }


}
