import 'package:flutter/material.dart';
import '../monitoring/error_tracker.dart';

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
}

class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is NetworkException) {
      return 'خطأ في الاتصال بالشبكة: ${error.message}';
    } else if (error is AuthException) {
      return 'خطأ في المصادقة: ${error.message}';
    } else if (error is ValidationException) {
      return 'خطأ في البيانات: ${error.message}';
    } else {
      return 'حدث خطأ غير متوقع';
    }
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  static void logError(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    ErrorTracker().recordError(
      error ?? message,
      stackTrace,
      reason: message,
      information: extra?.entries.map((e) => '${e.key}: ${e.value}').toList(),
    );
  }
} 