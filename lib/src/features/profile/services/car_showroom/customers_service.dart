import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/car_showroom/customer_model.dart';

/// Service للتعامل مع العملاء في Firestore
///
/// يوفر وظائف CRUD كاملة للعملاء
/// Collection: `customers`
class CustomersService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'customers';

  /// جلب جميع عملاء البائع المحدد
  Future<List<CustomerModel>> getCustomers(String sellerId) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) => CustomerModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting customers: $e');
      throw 'فشل في تحميل العملاء. الرجاء المحاولة مرة أخرى';
    }
  }

  /// جلب عميل بواسطة المعرف
  Future<CustomerModel?> getCustomer(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return CustomerModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting customer: $e');
      rethrow;
    }
  }

  /// إضافة عميل جديد
  Future<String> addCustomer(CustomerModel customer) async {
    try {
      _validateCustomerData(customer);

      final customerData = customer.toFirestore();
      customerData['createdAt'] = FieldValue.serverTimestamp();
      customerData['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = await _db.collection(_collection).add(customerData);
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding customer: $e');
      throw 'فشل في إضافة العميل. الرجاء المحاولة مرة أخرى';
    }
  }

  /// تحديث بيانات عميل
  Future<void> updateCustomer(CustomerModel customer) async {
    try {
      _validateCustomerData(customer);

      final customerData = customer.toFirestore();
      customerData['updatedAt'] = FieldValue.serverTimestamp();

      await _db.collection(_collection).doc(customer.id).update(customerData);
    } catch (e) {
      debugPrint('Error updating customer: $e');
      throw 'فشل في تحديث بيانات العميل. الرجاء المحاولة مرة أخرى';
    }
  }

  /// حذف عميل
  Future<void> deleteCustomer(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      throw 'فشل في حذف العميل. الرجاء المحاولة مرة أخرى';
    }
  }

  /// التحقق من صحة بيانات العميل
  void _validateCustomerData(CustomerModel customer) {
    if (customer.name.isEmpty) {
      throw 'اسم العميل مطلوب';
    }
    if (customer.phone.isEmpty) {
      throw 'رقم الجوال مطلوب';
    }
    if (customer.sellerId.isEmpty) {
      throw 'معرف البائع مطلوب';
    }
  }

  /// Stream للاستماع لتغييرات العملاء
  Stream<List<CustomerModel>> watchCustomers(String sellerId) {
    return _db
        .collection(_collection)
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CustomerModel.fromFirestore(doc))
          .toList();
    });
  }
}
