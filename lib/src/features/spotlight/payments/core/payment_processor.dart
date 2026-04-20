import 'package:flutter/services.dart';
import '../../../../core/utils/logger.dart';
import '../../models/spotlight_plan.dart';
import 'payment_manager.dart';
import 'payment_result.dart';

/// معالج الدفع للاشتراكات
class PaymentProcessor {
  final PaymentManager _paymentManager;

  PaymentProcessor(this._paymentManager);

  /// تهيئة معالج الدفع
  Future<bool> initialize() async {
    try {
      logInfo('جاري تهيئة معالج الدفع...');
      final initialized = await _paymentManager.initializeMada();
      if (!initialized) {
        logError('فشل في تهيئة معالج الدفع');
        return false;
      }
      logInfo('تم تهيئة معالج الدفع بنجاح');
      return true;
    } catch (e) {
      logError('خطأ في تهيئة معالج الدفع', e);
      return false;
    }
  }

  /// معالجة عملية الدفع
  Future<bool> processPayment(SpotlightPlan plan, String userId) async {
    try {
      if (userId.isEmpty) {
        logError('processPayment: userId is empty');
        return false;
      }
      // التحقق من صحة خطة الاشتراك
      if (!_validatePlan(plan)) {
        logError('Invalid subscription plan');
        return false;
      }

      // معالجة الدفع
      final result = await _paymentManager.processPayment(
        amount: plan.price,
        currency: 'SAR',
        description: plan.description,
        userId: userId,
      );

      if (result.success) {
        logInfo('Payment processed successfully');
        return true;
      } else {
        logError('Payment processing failed: ${result.error}');
        return false;
      }
    } catch (e) {
      logError('Error processing payment', e);
      return false;
    }
  }

  /// التحقق من صحة خطة الاشتراك
  bool _validatePlan(SpotlightPlan plan) {
    return plan.price > 0 && plan.durationInDays > 0;
  }

  Future<PaymentResult> processMadaPayment({
    required double amount,
    required String currency,
    required String description,
    required String userId,
  }) async {
    try {
      logInfo('بدء عملية الدفع بمدى');
      
      // تهيئة بوابة مدى
      logInfo('جاري تهيئة بوابة مدى...');
      final initialized = await _paymentManager.initializeMada();
      if (!initialized) {
        logError('فشل في تهيئة بوابة مدى');
        return PaymentResult(
          success: false,
          error: 'فشل في تهيئة بوابة الدفع',
        );
      }
      logInfo('تم تهيئة بوابة مدى بنجاح');

      // معالجة الدفع
      logInfo('جاري معالجة الدفع...');
      final result = await _paymentManager.processPayment(
        amount: amount,
        currency: currency,
        description: description,
        userId: userId,
      );
      
      if (result.success) {
        logInfo('تم معالجة الدفع بنجاح');
      } else {
        logError('فشل في معالجة الدفع: ${result.error}');
      }
      
      return result;
    } on PlatformException catch (e) {
      logError('خطأ في النظام الأساسي', e);
      return PaymentResult(
        success: false,
        error: e.message ?? 'حدث خطأ غير معروف',
      );
    } catch (e) {
      logError('خطأ غير متوقع', e);
      return PaymentResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// التحقق من حالة الدفع
  Future<PaymentResult> checkPaymentStatus(String transactionId) async {
    return await _paymentManager.checkPaymentStatus(transactionId);
  }

  /// إلغاء عملية الدفع
  Future<bool> cancelPayment(String transactionId) async {
    return await _paymentManager.cancelPayment(transactionId);
  }
} 