import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/real_estate/rental_payment_model.dart';

/// Service للتعامل مع دفعات الإيجار في Firestore
///
/// يوفر وظائف CRUD كاملة لدفعات الإيجار
/// Collection: `rental_payments`
class RentalPaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'rental_payments';

  /// جلب جميع دفعات عقد إيجار معين
  Future<List<RentalPaymentModel>> getPaymentsByRental(String rentalId) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('rentalId', isEqualTo: rentalId)
          .orderBy('dueDate', descending: false)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) => RentalPaymentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting payments: $e');
      throw 'فشل في تحميل الدفعات. الرجاء المحاولة مرة أخرى';
    }
  }

  /// جلب دفعة بواسطة المعرف
  Future<RentalPaymentModel?> getPayment(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return RentalPaymentModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting payment: $e');
      rethrow;
    }
  }

  /// إضافة دفعة جديدة
  Future<String> addPayment(RentalPaymentModel payment) async {
    try {
      _validatePaymentData(payment);

      final paymentData = payment.toFirestore();
      paymentData['createdAt'] = FieldValue.serverTimestamp();
      paymentData['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = await _db.collection(_collection).add(paymentData);
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding payment: $e');
      throw 'فشل في تسجيل الدفعة. الرجاء المحاولة مرة أخرى';
    }
  }

  /// إنشاء جدول دفعات لعقد إيجار
  Future<List<String>> createPaymentSchedule({
    required String rentalId,
    required double monthlyRent,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final List<String> paymentIds = [];
      final months = _calculateMonthsBetween(startDate, endDate);

      for (int i = 0; i < months; i++) {
        final dueDate = DateTime(
          startDate.year,
          startDate.month + i,
          startDate.day,
        );

        final payment = RentalPaymentModel(
          id: '',
          rentalId: rentalId,
          amount: monthlyRent,
          dueDate: dueDate,
          status: PaymentStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final paymentId = await addPayment(payment);
        paymentIds.add(paymentId);
      }

      return paymentIds;
    } catch (e) {
      debugPrint('Error creating payment schedule: $e');
      throw 'فشل في إنشاء جدول الدفعات. الرجاء المحاولة مرة أخرى';
    }
  }

  /// تسجيل دفع دفعة
  Future<void> recordPayment(
    String paymentId, {
    required DateTime paidDate,
    String? receiptNumber,
    String? notes,
  }) async {
    try {
      final payment = await getPayment(paymentId);
      if (payment == null) {
        throw 'الدفعة غير موجودة';
      }

      final updatedPayment = payment.copyWith(
        paidDate: paidDate,
        status: PaymentStatus.paid,
        receiptNumber: receiptNumber,
        notes: notes,
        updatedAt: DateTime.now(),
      );

      await updatePayment(updatedPayment);
    } catch (e) {
      debugPrint('Error recording payment: $e');
      throw 'فشل في تسجيل الدفعة. الرجاء المحاولة مرة أخرى';
    }
  }

  /// تحديث بيانات دفعة
  Future<void> updatePayment(RentalPaymentModel payment) async {
    try {
      _validatePaymentData(payment);

      final paymentData = payment.toFirestore();
      paymentData['updatedAt'] = FieldValue.serverTimestamp();

      await _db.collection(_collection).doc(payment.id).update(paymentData);
    } catch (e) {
      debugPrint('Error updating payment: $e');
      throw 'فشل في تحديث الدفعة. الرجاء المحاولة مرة أخرى';
    }
  }

  /// حذف دفعة
  Future<void> deletePayment(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting payment: $e');
      throw 'فشل في حذف الدفعة. الرجاء المحاولة مرة أخرى';
    }
  }

  /// جلب الدفعات المستحقة
  Future<List<RentalPaymentModel>> getDuePayments(String ownerId) async {
    try {
      final now = DateTime.now();
      final thresholdDate = now.add(const Duration(days: 7));

      // ✅ جلب جميع عقود الإيجار للمالك
      final rentalsSnapshot = await _db
          .collection('rentals')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      if (rentalsSnapshot.docs.isEmpty) {
        return [];
      }

      final rentalIds = rentalsSnapshot.docs.map((doc) => doc.id).toList();

      // ✅ جلب الدفعات المستحقة
      final paymentsSnapshot = await _db
          .collection(_collection)
          .where('rentalId', whereIn: rentalIds)
          .where('status', isEqualTo: PaymentStatus.pending.toString().split('.').last)
          .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(thresholdDate))
          .orderBy('dueDate', descending: false)
          .get();

      if (paymentsSnapshot.docs.isEmpty) {
        return [];
      }

      return paymentsSnapshot.docs
          .map((doc) => RentalPaymentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting due payments: $e');
      throw 'فشل في تحميل الدفعات المستحقة. الرجاء المحاولة مرة أخرى';
    }
  }

  /// جلب الدفعات المتأخرة
  Future<List<RentalPaymentModel>> getOverduePayments(String ownerId) async {
    try {
      final now = DateTime.now();

      // ✅ جلب جميع عقود الإيجار للمالك
      final rentalsSnapshot = await _db
          .collection('rentals')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      if (rentalsSnapshot.docs.isEmpty) {
        return [];
      }

      final rentalIds = rentalsSnapshot.docs.map((doc) => doc.id).toList();

      // ✅ جلب الدفعات المتأخرة
      final paymentsSnapshot = await _db
          .collection(_collection)
          .where('rentalId', whereIn: rentalIds)
          .where('status', whereIn: [
            PaymentStatus.pending.toString().split('.').last,
            PaymentStatus.due.toString().split('.').last,
          ])
          .where('dueDate', isLessThan: Timestamp.fromDate(now))
          .orderBy('dueDate', descending: false)
          .get();

      if (paymentsSnapshot.docs.isEmpty) {
        return [];
      }

      return paymentsSnapshot.docs
          .map((doc) {
            final payment = RentalPaymentModel.fromFirestore(doc);
            // ✅ تحديث الحالة إلى "متأخر" إذا كانت "مستحق"
            if (payment.status == PaymentStatus.due) {
              return payment.copyWith(status: PaymentStatus.overdue);
            }
            return payment;
          })
          .toList();
    } catch (e) {
      debugPrint('Error getting overdue payments: $e');
      throw 'فشل في تحميل الدفعات المتأخرة. الرجاء المحاولة مرة أخرى';
    }
  }

  /// حساب عدد الأشهر بين تاريخين
  int _calculateMonthsBetween(DateTime start, DateTime end) {
    final years = end.year - start.year;
    final months = end.month - start.month;
    return (years * 12) + months;
  }

  /// التحقق من صحة بيانات الدفعة
  void _validatePaymentData(RentalPaymentModel payment) {
    if (payment.rentalId.isEmpty) {
      throw 'معرف عقد الإيجار مطلوب';
    }
    if (payment.amount <= 0) {
      throw 'مبلغ الدفعة يجب أن يكون أكبر من صفر';
    }
  }

  /// Stream للاستماع لتغييرات دفعات عقد إيجار
  Stream<List<RentalPaymentModel>> watchPayments(String rentalId) {
    return _db
        .collection(_collection)
        .where('rentalId', isEqualTo: rentalId)
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RentalPaymentModel.fromFirestore(doc))
          .toList();
    });
  }
}
