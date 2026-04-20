// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show AnchorElement, Blob, Url;
import 'dart:typed_data';

/// ✅ دالة مساعدة للويب - تنزيل الملف مباشرة
void downloadFileForWeb(Uint8List fileBytes, String fileName) {
  final blob = html.Blob([fileBytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
