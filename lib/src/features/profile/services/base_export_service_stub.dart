import 'dart:typed_data';

/// ✅ Stub file للموبايل - لا يحتوي على أي كود
/// هذا الملف موجود فقط لتفادي أخطاء conditional import
void downloadFileForWeb(Uint8List fileBytes, String fileName) {
  // ✅ هذا الكود لن يُستدعى أبداً على الموبايل
  // لأننا نستخدم kIsWeb check قبل استدعائه
  throw UnsupportedError('downloadFileForWeb is only available on web');
}
