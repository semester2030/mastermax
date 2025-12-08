import 'package:flutter/foundation.dart';
import '../models/spotlight_plan.dart';

class SubscriptionResult {
  final bool success;
  final String? message;
  final String? transactionId;
  final String? errorCode;

  const SubscriptionResult({
    required this.success,
    this.message,
    this.transactionId,
    this.errorCode,
  });
}

class SubscriptionService {
  bool _isInitialized = false;

  SubscriptionService();

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize subscription service
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing subscription service: $e');
      rethrow;
    }
  }

  Future<SubscriptionResult> subscribe({
    required String planId,
    required String paymentMethod,
    required double amount,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final plan = SpotlightPlan.plans.firstWhere(
        (plan) => plan.id == planId,
        orElse: () => throw Exception('خطة الاشتراك غير موجودة'),
      );

      if (amount != plan.price) {
        return const SubscriptionResult(
          success: false,
          message: 'المبلغ المدخل غير مطابق لسعر الباقة',
          errorCode: 'INVALID_AMOUNT',
        );
      }

      switch (paymentMethod) {
        case 'mada':
          return SubscriptionResult(
            success: true,
            message: 'تم الدفع بنجاح (وضع التطوير)',
            transactionId: 'dev_${DateTime.now().millisecondsSinceEpoch}',
          );
          
        case 'bank':
          return const SubscriptionResult(
            success: true,
            message: 'تم إنشاء طلب التحويل البنكي بنجاح',
          );
          
        default:
          return const SubscriptionResult(
            success: false,
            message: 'طريقة الدفع غير مدعومة',
            errorCode: 'INVALID_PAYMENT_METHOD',
          );
      }
    } catch (e) {
      debugPrint('خطأ في خدمة الاشتراك: $e');
      return const SubscriptionResult(
        success: false,
        message: 'حدث خطأ أثناء الاشتراك',
        errorCode: 'SUBSCRIPTION_ERROR',
      );
    }
  }

  Future<bool> cancelSubscription() async {
    try {
      // قم بإلغاء الاشتراك
      return true;
    } catch (e) {
      debugPrint('Error canceling subscription: $e');
      return false;
    }
  }
} 