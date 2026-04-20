import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/logger.dart';
import '../models/spotlight_plan.dart';
import '../payments/core/payment_processor.dart';

/// خدمة إدارة الاشتراكات في سبوتلايت
class SpotlightSubscriptionService {
  final PaymentProcessor _paymentProcessor;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SpotlightSubscriptionService(this._paymentProcessor);

  /// بدء اشتراك جديد
  Future<bool> startSubscription(SpotlightPlan plan, String userId) async {
    try {
      final success = await _paymentProcessor.processPayment(plan, userId);
      if (success) {
        // تحديث حالة الاشتراك في قاعدة البيانات
        await _updateSubscriptionStatus(
          userId: userId,
          plan: plan,
          paymentMethod: 'direct',
          paymentId: DateTime.now().millisecondsSinceEpoch.toString(),
          status: 'active',
        );
        return true;
      }
      return false;
    } catch (e) {
      logError('Error starting subscription', e);
      return false;
    }
  }

  /// إلغاء الاشتراك
  Future<bool> cancelSubscription(String userId) async {
    try {
      await _firestore.collection('subscriptions').doc(userId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      logError('Error canceling subscription', e);
      return false;
    }
  }

  /// التحقق من حالة الاشتراك
  Future<bool> isSubscriptionActive(String userId) async {
    try {
      final doc = await _firestore.collection('subscriptions').doc(userId).get();
      if (!doc.exists) return false;
      
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'active' && 
             (data['endDate'] as Timestamp).toDate().isAfter(DateTime.now());
    } catch (e) {
      logError('Error checking subscription status', e);
      return false;
    }
  }

  Future<bool> processMadaPayment({
    required SpotlightPlan plan,
    required String userId,
  }) async {
    try {
      // معالجة الدفع بمدى
      final paymentResult = await _paymentProcessor.processMadaPayment(
        amount: plan.price,
        currency: 'SAR',
        description: 'اشتراك في ${plan.name}',
        userId: userId,
      );

      if (paymentResult.success) {
        // تحديث حالة الاشتراك في قاعدة البيانات
        await _updateSubscriptionStatus(
          userId: userId,
          plan: plan,
          paymentMethod: 'mada',
          paymentId: paymentResult.transactionId ?? '',
          status: 'active',
        );
        return true;
      }
      return false;
    } catch (e) {
      logError('Error processing Mada payment', e);
      return false;
    }
  }

  Future<bool> confirmBankTransfer({
    required SpotlightPlan plan,
    required String userId,
    required String referenceNumber,
  }) async {
    try {
      // تسجيل طلب التحويل البنكي
      await _firestore.collection('bank_transfers').add({
        'userId': userId,
        'planId': plan.id,
        'amount': plan.price,
        'referenceNumber': referenceNumber,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // تحديث حالة الاشتراك في قاعدة البيانات
      await _updateSubscriptionStatus(
        userId: userId,
        plan: plan,
        paymentMethod: 'bank_transfer',
        paymentId: referenceNumber,
        status: 'pending',
      );

      return true;
    } catch (e) {
      logError('Error confirming bank transfer', e);
      return false;
    }
  }

  /// تحديث حالة الاشتراك في قاعدة البيانات
  Future<void> _updateSubscriptionStatus({
    required String userId,
    required SpotlightPlan plan,
    required String paymentMethod,
    required String paymentId,
    required String status,
  }) async {
    await _firestore.collection('subscriptions').doc(userId).set({
      'userId': userId,
      'planId': plan.id,
      'planName': plan.name,
      'price': plan.price,
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentId': paymentId,
      'startDate': status == 'active' ? FieldValue.serverTimestamp() : null,
      'endDate': status == 'active'
          ? Timestamp.fromDate(
              DateTime.now().add(Duration(days: plan.durationInDays)),
            )
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
} 