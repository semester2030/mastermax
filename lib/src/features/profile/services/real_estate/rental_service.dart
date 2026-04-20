import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/real_estate/rental_model.dart';

/// Service للتعامل مع عقود الإيجار في Firestore
///
/// يوفر وظائف CRUD كاملة لعقود الإيجار
/// Collection: `rentals`
class RentalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'rentals';

  /// جلب جميع عقود الإيجار للمالك المحدد
  Future<List<RentalModel>> getRentals(String ownerId) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('ownerId', isEqualTo: ownerId)
          .orderBy('startDate', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) => RentalModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting rentals: $e');
      
      // التحقق من خطأ الفهرس المفقود
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('index') || errorString.contains('requires an index')) {
        debugPrint('⚠️ Firestore index missing. Trying without orderBy...');
        try {
          // محاولة بدون orderBy كحل مؤقت
          final snapshot = await _db
              .collection(_collection)
              .where('ownerId', isEqualTo: ownerId)
              .get();

          if (snapshot.docs.isEmpty) {
            return [];
          }

          final rentals = snapshot.docs
              .map((doc) => RentalModel.fromFirestore(doc))
              .toList();
          
          // ترتيب يدوي
          rentals.sort((a, b) => b.startDate.compareTo(a.startDate));
          return rentals;
        } catch (fallbackError) {
          debugPrint('Fallback also failed: $fallbackError');
          throw 'فشل في تحميل عقود الإيجار. يرجى التحقق من إعدادات Firestore';
        }
      }
      
      throw 'فشل في تحميل عقود الإيجار. الرجاء المحاولة مرة أخرى';
    }
  }

  /// جلب العقود النشطة فقط
  Future<List<RentalModel>> getActiveRentals(String ownerId) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: RentalStatus.active.toString().split('.').last)
          .orderBy('startDate', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) => RentalModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting active rentals: $e');
      
      // التحقق من خطأ الفهرس المفقود
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('index') || errorString.contains('requires an index')) {
        debugPrint('⚠️ Firestore index missing. Trying without orderBy...');
        try {
          // محاولة بدون orderBy كحل مؤقت
          final snapshot = await _db
              .collection(_collection)
              .where('ownerId', isEqualTo: ownerId)
              .where('status', isEqualTo: RentalStatus.active.toString().split('.').last)
              .get();

          if (snapshot.docs.isEmpty) {
            return [];
          }

          final rentals = snapshot.docs
              .map((doc) => RentalModel.fromFirestore(doc))
              .toList();
          
          // ترتيب يدوي
          rentals.sort((a, b) => b.startDate.compareTo(a.startDate));
          return rentals;
        } catch (fallbackError) {
          debugPrint('Fallback also failed: $fallbackError');
          throw 'فشل في تحميل العقود النشطة. يرجى التحقق من إعدادات Firestore';
        }
      }
      
      throw 'فشل في تحميل العقود النشطة. الرجاء المحاولة مرة أخرى';
    }
  }

  /// جلب عقود الإيجار لعقار معين
  Future<List<RentalModel>> getRentalsByProperty(String propertyId) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('propertyId', isEqualTo: propertyId)
          .orderBy('startDate', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) => RentalModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting rentals by property: $e');
      
      // التحقق من خطأ الفهرس المفقود
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('index') || errorString.contains('requires an index')) {
        debugPrint('⚠️ Firestore index missing. Trying without orderBy...');
        try {
          // محاولة بدون orderBy كحل مؤقت
          final snapshot = await _db
              .collection(_collection)
              .where('propertyId', isEqualTo: propertyId)
              .get();

          if (snapshot.docs.isEmpty) {
            return [];
          }

          final rentals = snapshot.docs
              .map((doc) => RentalModel.fromFirestore(doc))
              .toList();
          
          // ترتيب يدوي
          rentals.sort((a, b) => b.startDate.compareTo(a.startDate));
          return rentals;
        } catch (fallbackError) {
          debugPrint('Fallback also failed: $fallbackError');
          throw 'فشل في تحميل عقود الإيجار. يرجى التحقق من إعدادات Firestore';
        }
      }
      
      throw 'فشل في تحميل عقود الإيجار. الرجاء المحاولة مرة أخرى';
    }
  }

  /// جلب عقد إيجار بواسطة المعرف
  Future<RentalModel?> getRental(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return RentalModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting rental: $e');
      rethrow;
    }
  }

  /// إضافة عقد إيجار جديد
  Future<String> addRental(RentalModel rental) async {
    try {
      _validateRentalData(rental);

      final rentalData = rental.toFirestore();
      rentalData['createdAt'] = FieldValue.serverTimestamp();
      rentalData['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = await _db.collection(_collection).add(rentalData);
      
      // ✅ تحديث حالة العقار إلى "مؤجر"
      await _updatePropertyStatus(rental.propertyId, true);
      
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding rental: $e');
      throw 'فشل في تسجيل عقد الإيجار. الرجاء المحاولة مرة أخرى';
    }
  }

  /// تحديث بيانات عقد إيجار
  Future<void> updateRental(RentalModel rental) async {
    try {
      _validateRentalData(rental);

      final rentalData = rental.toFirestore();
      rentalData['updatedAt'] = FieldValue.serverTimestamp();

      await _db.collection(_collection).doc(rental.id).update(rentalData);
    } catch (e) {
      debugPrint('Error updating rental: $e');
      throw 'فشل في تحديث عقد الإيجار. الرجاء المحاولة مرة أخرى';
    }
  }

  /// حذف عقد إيجار
  Future<void> deleteRental(String id, String propertyId) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      
      // ✅ تحديث حالة العقار إلى "متاح"
      await _updatePropertyStatus(propertyId, false);
    } catch (e) {
      debugPrint('Error deleting rental: $e');
      throw 'فشل في حذف عقد الإيجار. الرجاء المحاولة مرة أخرى';
    }
  }

  /// تجديد عقد إيجار
  Future<String> renewRental(RentalModel oldRental, DateTime newEndDate) async {
    try {
      // ✅ تحديث العقد القديم إلى "مجدد"
      final updatedOldRental = oldRental.copyWith(
        status: RentalStatus.renewed,
        updatedAt: DateTime.now(),
      );
      await updateRental(updatedOldRental);

      // ✅ إنشاء عقد جديد
      final newRental = oldRental.copyWith(
        id: '',
        startDate: oldRental.endDate,
        endDate: newEndDate,
        status: RentalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return await addRental(newRental);
    } catch (e) {
      debugPrint('Error renewing rental: $e');
      throw 'فشل في تجديد عقد الإيجار. الرجاء المحاولة مرة أخرى';
    }
  }

  /// إلغاء عقد إيجار
  Future<void> cancelRental(String id, String propertyId) async {
    try {
      final rental = await getRental(id);
      if (rental == null) {
        throw 'عقد الإيجار غير موجود';
      }

      final updatedRental = rental.copyWith(
        status: RentalStatus.cancelled,
        updatedAt: DateTime.now(),
      );
      await updateRental(updatedRental);

      // ✅ تحديث حالة العقار إلى "متاح"
      await _updatePropertyStatus(propertyId, false);
    } catch (e) {
      debugPrint('Error cancelling rental: $e');
      throw 'فشل في إلغاء عقد الإيجار. الرجاء المحاولة مرة أخرى';
    }
  }

  /// تحديث حالة العقار (مؤجر/متاح)
  Future<void> _updatePropertyStatus(String propertyId, bool isRented) async {
    try {
      await _db.collection('properties').doc(propertyId).update({
        'status': isRented 
            ? 'rented' // ✅ استخدام string مباشر (مثل 'sold' في sales_management_viewmodel)
            : 'available',
        'isAvailable': !isRented,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating property status: $e');
      // لا نرمي خطأ هنا لأن تحديث حالة العقار ليس ضرورياً
    }
  }

  /// التحقق من صحة بيانات عقد الإيجار
  void _validateRentalData(RentalModel rental) {
    if (rental.propertyId.isEmpty) {
      throw 'معرف العقار مطلوب';
    }
    if (rental.customerId.isEmpty) {
      throw 'معرف العميل مطلوب';
    }
    if (rental.monthlyRent <= 0) {
      throw 'الإيجار الشهري يجب أن يكون أكبر من صفر';
    }
    if (rental.ownerId.isEmpty) {
      throw 'معرف المالك مطلوب';
    }
    if (rental.endDate.isBefore(rental.startDate)) {
      throw 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية';
    }
  }

  /// Stream للاستماع لتغييرات عقود الإيجار
  Stream<List<RentalModel>> watchRentals(String ownerId) {
    return _db
        .collection(_collection)
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RentalModel.fromFirestore(doc))
          .toList();
    });
  }

  /// جلب العقود القريبة من الانتهاء (أقل من 30 يوم)
  Future<List<RentalModel>> getExpiringRentals(String ownerId, {int daysThreshold = 30}) async {
    try {
      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      final snapshot = await _db
          .collection(_collection)
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: RentalStatus.active.toString().split('.').last)
          .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(thresholdDate))
          .where('endDate', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('endDate', descending: false)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) => RentalModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting expiring rentals: $e');
      throw 'فشل في تحميل العقود القريبة من الانتهاء. الرجاء المحاولة مرة أخرى';
    }
  }
}
