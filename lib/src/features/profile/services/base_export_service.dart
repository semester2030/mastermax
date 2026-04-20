import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
// ✅ Conditional import للويب والموبايل
import 'base_export_service_stub.dart'
    if (dart.library.html) 'base_export_service_web.dart' as web_helper;

/// Base class للخدمات المشتركة في التصدير
///
/// يحتوي على الكود المشترك بين ExportService و RealEstateExportService
/// لتجنب التكرار في الكود
abstract class BaseExportService {
  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ar');
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd', 'ar');

  NumberFormat get numberFormat => _numberFormat;
  DateFormat get dateFormat => _dateFormat;

  /// بناء صف إحصائي (مشترك)
  pw.Widget buildStatRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(label),
        ],
      ),
    );
  }

  /// بناء خلية جدول (مشترك)
  pw.Widget buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 12 : 10,
        ),
      ),
    );
  }

  /// مشاركة الملف (مشترك)
  Future<void> shareFile(String filePath, {String? text, BuildContext? context, Uint8List? fileBytes, String? fileName}) async {
    try {
      if (kIsWeb) {
        // ✅ للويب: تنزيل الملف مباشرة باستخدام web_helper
        if (fileBytes != null && fileName != null) {
          web_helper.downloadFileForWeb(fileBytes, fileName);
          return;
        }
        // ✅ محاولة استخدام filePath كاسم ملف إذا لم يتم توفير fileBytes
        if (fileName == null && filePath.isNotEmpty) {
          final name = filePath.split('/').last;
          if (name.isNotEmpty) {
            // ✅ للويب: إذا كان لدينا fileBytes من export service
            // سيتم التعامل معه في RealEstateExportService
            throw 'يجب توفير fileBytes للويب';
          }
        }
        throw 'يجب توفير fileBytes و fileName للويب';
      }
      
      // ✅ للموبايل: استخدام share_plus
      ShareParams params;
      
      if (Platform.isIOS) {
        // ✅ على iOS، يجب تحديد sharePositionOrigin
        Rect? sharePositionOrigin;
        
        if (context != null) {
          try {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
            }
          } catch (e) {
            debugPrint('Error getting sharePositionOrigin: $e');
          }
        }
        
        // ✅ استخدام قيمة افتراضية إذا لم نتمكن من الحصول على position
        sharePositionOrigin ??= const Rect.fromLTWH(0, 0, 1, 1);
        
        params = ShareParams(
          files: [XFile(filePath)],
          text: text ?? 'تقرير',
          sharePositionOrigin: sharePositionOrigin,
        );
      } else {
        // ✅ على Android وغير iOS، لا حاجة لـ sharePositionOrigin
        params = ShareParams(
          files: [XFile(filePath)],
          text: text ?? 'تقرير',
        );
      }
      
      // ✅ استخدام SharePlus.instance.share() بدلاً من Share.shareXFiles (deprecated)
      await SharePlus.instance.share(params);
    } catch (e) {
      debugPrint('Error sharing file: $e');
      rethrow;
    }
  }
}
