import 'package:flutter/services.dart';
import '../../../../core/utils/logger.dart';
import 'payment_result.dart';

class PaymentManager {
  static const platform = MethodChannel('com.mastermax.payment/mada');

  /// تهيئة بوابة مدى
  Future<bool> initializeMada() async {
    try {
      logInfo('محاولة تهيئة بوابة مدى عبر Method Channel');
      final result = await platform.invokeMethod<bool>('initializeMada');
      logInfo('نتيجة تهيئة مدى: ${result ?? false}');
      return result ?? false;
    } catch (e) {
      logError('خطأ في تهيئة مدى', e);
      return false;
    }
  }

  /// معالجة عملية الدفع
  Future<PaymentResult> processPayment({
    required double amount,
    required String currency,
    required String description,
    required String userId,
  }) async {
    try {
      logInfo('إرسال طلب الدفع عبر Method Channel');
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>('processPayment', {
        'amount': amount,
        'currency': currency,
        'description': description,
        'userId': userId,
      });

      if (result == null) {
        logError('لم يتم استلام نتيجة من Method Channel');
        return PaymentResult(
          success: false,
          error: 'فشل في معالجة الدفع',
        );
      }

      logInfo('تم استلام نتيجة الدفع: $result');
      return PaymentResult(
        success: result['success'] as bool? ?? false,
        transactionId: result['transactionId'] as String?,
        error: result['error'] as String?,
      );
    } catch (e) {
      logError('خطأ في معالجة الدفع', e);
      return PaymentResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// التحقق من حالة الدفع
  Future<PaymentResult> checkPaymentStatus(String transactionId) async {
    try {
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>('checkPaymentStatus', {
        'transactionId': transactionId,
      });

      if (result == null) {
        return PaymentResult(
          success: false,
          error: 'فشل في التحقق من حالة الدفع',
        );
      }

      return PaymentResult(
        success: result['success'] as bool? ?? false,
        transactionId: transactionId,
        error: result['error'] as String?,
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// إلغاء عملية الدفع
  Future<bool> cancelPayment(String transactionId) async {
    try {
      final result = await platform.invokeMethod<bool>('cancelPayment', {
        'transactionId': transactionId,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
} 