import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/real_estate/real_estate_customer_model.dart';

/// Service للتعامل مع عملاء العقارات في Firestore
///
/// يوفر وظائف CRUD كاملة للعملاء
/// Collection: `real_estate_customers`
class RealEstateCustomersService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'real_estate_customers';

  /// جلب جميع عملاء الشركة/الوسيط المحدد
  Future<List<RealEstateCustomerModel>> getCustomers(String companyId) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) => RealEstateCustomerModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting real estate customers: $e');
      
      // التحقق من خطأ الفهرس المفقود
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('index') || errorString.contains('requires an index')) {
        debugPrint('⚠️ Firestore index missing. Trying without orderBy...');
        try {
          // محاولة بدون orderBy كحل مؤقت
          final snapshot = await _db
              .collection(_collection)
              .where('companyId', isEqualTo: companyId)
              .get();

          if (snapshot.docs.isEmpty) {
            return [];
          }

          final customers = snapshot.docs
              .map((doc) => RealEstateCustomerModel.fromFirestore(doc))
              .toList();
          
          // ترتيب يدوي
          customers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return customers;
        } catch (fallbackError) {
          debugPrint('Fallback also failed: $fallbackError');
          throw 'فشل في تحميل العملاء. يرجى التحقق من إعدادات Firestore';
        }
      }
      
      throw 'فشل في تحميل العملاء. الرجاء المحاولة مرة أخرى';
    }
  }

  /// جلب عميل بواسطة المعرف
  Future<RealEstateCustomerModel?> getCustomer(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return RealEstateCustomerModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting customer: $e');
      rethrow;
    }
  }

  /// إضافة عميل جديد
  Future<String> addCustomer(RealEstateCustomerModel customer) async {
    try {
      _validateCustomerData(customer);

      final docRef = await _db.collection(_collection).add(customer.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding customer: $e');
      if (e is String) rethrow;
      throw 'فشل في إضافة العميل. الرجاء المحاولة مرة أخرى';
    }
  }

  /// تحديث بيانات عميل
  Future<void> updateCustomer(RealEstateCustomerModel customer) async {
    try {
      _validateCustomerData(customer);

      if (customer.id.isEmpty) {
        throw 'معرف العميل مطلوب للتحديث';
      }

      await _db
          .collection(_collection)
          .doc(customer.id)
          .update(customer.toFirestore());
    } catch (e) {
      debugPrint('Error updating customer: $e');
      if (e is String) rethrow;
      throw 'فشل في تحديث بيانات العميل. الرجاء المحاولة مرة أخرى';
    }
  }

  /// حذف عميل
  Future<void> deleteCustomer(String id) async {
    try {
      if (id.isEmpty) {
        throw 'معرف العميل مطلوب للحذف';
      }

      await _db.collection(_collection).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      if (e is String) rethrow;
      throw 'فشل في حذف العميل. الرجاء المحاولة مرة أخرى';
    }
  }

  /// Stream للحصول على قائمة العملاء بشكل مباشر
  Stream<List<RealEstateCustomerModel>> watchCustomers(String companyId) {
    return _db
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RealEstateCustomerModel.fromFirestore(doc))
            .toList());
  }

  /// التحقق من صحة بيانات العميل
  void _validateCustomerData(RealEstateCustomerModel customer) {
    if (customer.companyId.isEmpty) {
      throw 'معرف الشركة/الوسيط مطلوب';
    }
    if (customer.name.trim().isEmpty) {
      throw 'اسم العميل مطلوب';
    }
    if (customer.phone.trim().isEmpty) {
      throw 'رقم الجوال مطلوب';
    }
  }
}
