import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/car_showroom/sale_model.dart';

/// Service للتعامل مع المبيعات في Firestore
///
/// يوفر وظائف CRUD كاملة للمبيعات
/// Collection: `sales`
class SalesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'sales';

  /// جلب جميع مبيعات البائع المحدد
  Future<List<SaleModel>> getSales(String sellerId) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('saleDate', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) => SaleModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting sales: $e');
      throw 'فشل في تحميل المبيعات. الرجاء المحاولة مرة أخرى';
    }
  }

  /// جلب المبيعات ضمن فترة زمنية محددة
  Future<List<SaleModel>> getSalesByDateRange(
    String sellerId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate);

      final snapshot = await _db
          .collection(_collection)
          .where('sellerId', isEqualTo: sellerId)
          .where('saleDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('saleDate', isLessThanOrEqualTo: endTimestamp)
          .orderBy('saleDate', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) => SaleModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting sales by date range: $e');
      throw 'فشل في تحميل المبيعات. الرجاء المحاولة مرة أخرى';
    }
  }

  /// جلب عملية بيع بواسطة المعرف
  Future<SaleModel?> getSale(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return SaleModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting sale: $e');
      rethrow;
    }
  }

  /// إضافة عملية بيع جديدة
  Future<String> addSale(SaleModel sale) async {
    try {
      _validateSaleData(sale);

      final saleData = sale.toFirestore();
      saleData['createdAt'] = FieldValue.serverTimestamp();
      saleData['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = await _db.collection(_collection).add(saleData);
      
      // ✅ تحديث حالة السيارة في Firestore من "نشط" إلى "مباع" (isActive = false)
      await _updateCarStatus(sale.carId, false);
      
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding sale: $e');
      throw 'فشل في تسجيل عملية البيع. الرجاء المحاولة مرة أخرى';
    }
  }
  
  /// تحديث حالة السيارة (نشط/مباع)
  Future<void> _updateCarStatus(String carId, bool isActive) async {
    try {
      await _db.collection('cars').doc(carId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating car status: $e');
      // لا نرمي خطأ هنا - تحديث حالة السيارة ليس ضرورياً لعملية البيع
    }
  }

  /// تحديث بيانات عملية بيع
  Future<void> updateSale(SaleModel sale) async {
    try {
      _validateSaleData(sale);

      final saleData = sale.toFirestore();
      saleData['updatedAt'] = FieldValue.serverTimestamp();

      await _db.collection(_collection).doc(sale.id).update(saleData);
    } catch (e) {
      debugPrint('Error updating sale: $e');
      throw 'فشل في تحديث عملية البيع. الرجاء المحاولة مرة أخرى';
    }
  }

  /// حذف عملية بيع
  Future<void> deleteSale(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting sale: $e');
      throw 'فشل في حذف عملية البيع. الرجاء المحاولة مرة أخرى';
    }
  }

  /// التحقق من صحة بيانات عملية البيع
  void _validateSaleData(SaleModel sale) {
    if (sale.carId.isEmpty) {
      throw 'معرف السيارة مطلوب';
    }
    if (sale.customerId.isEmpty) {
      throw 'معرف العميل مطلوب';
    }
    if (sale.salePrice <= 0) {
      throw 'سعر البيع يجب أن يكون أكبر من صفر';
    }
    if (sale.sellerId.isEmpty) {
      throw 'معرف البائع مطلوب';
    }
  }

  /// Stream للاستماع لتغييرات المبيعات
  Stream<List<SaleModel>> watchSales(String sellerId) {
    return _db
        .collection(_collection)
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('saleDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SaleModel.fromFirestore(doc))
          .toList();
    });
  }
}
