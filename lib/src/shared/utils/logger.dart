import 'package:flutter/foundation.dart';

/// فئة مساعدة للتعامل مع السجلات بشكل آمن في الإنتاج
class Logger {
  /// تسجيل رسالة تصحيح
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('DEBUG: $message');
    }
  }

  /// تسجيل رسالة معلومات
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('INFO: $message');
    }
  }

  /// تسجيل رسالة تحذير
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('WARNING: $message');
    }
  }

  /// تسجيل رسالة خطأ
  static void error(String message) {
    if (kDebugMode) {
      debugPrint('ERROR: $message');
    }
  }
} 