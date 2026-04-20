import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/real_estate/branch_model.dart';

/// Service للتعامل مع الفروع في Firestore
///
/// يوفر وظائف CRUD كاملة للفروع
/// Collection: `branches`
class BranchesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'branches';

  /// جلب جميع فروع الشركة المحددة
  Future<List<BranchModel>> getBranches(String companyId) async {
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
          .map((doc) => BranchModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting branches: $e');
      
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

          final branches = snapshot.docs
              .map((doc) => BranchModel.fromFirestore(doc))
              .toList();
          
          // ترتيب يدوي
          branches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return branches;
        } catch (fallbackError) {
          debugPrint('Fallback also failed: $fallbackError');
          throw 'فشل في تحميل الفروع. يرجى التحقق من إعدادات Firestore';
        }
      }
      
      throw 'فشل في تحميل الفروع. الرجاء المحاولة مرة أخرى';
    }
  }

  /// جلب فرع بواسطة المعرف
  Future<BranchModel?> getBranch(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return BranchModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting branch: $e');
      rethrow;
    }
  }

  /// إضافة فرع جديد
  Future<String> addBranch(BranchModel branch) async {
    try {
      _validateBranchData(branch);

      final docRef = await _db.collection(_collection).add(branch.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding branch: $e');
      if (e is String) rethrow;
      throw 'فشل في إضافة الفرع. الرجاء المحاولة مرة أخرى';
    }
  }

  /// تحديث بيانات فرع
  Future<void> updateBranch(BranchModel branch) async {
    try {
      _validateBranchData(branch);

      if (branch.id.isEmpty) {
        throw 'معرف الفرع مطلوب للتحديث';
      }

      await _db
          .collection(_collection)
          .doc(branch.id)
          .update(branch.toFirestore());
    } catch (e) {
      debugPrint('Error updating branch: $e');
      if (e is String) rethrow;
      throw 'فشل في تحديث بيانات الفرع. الرجاء المحاولة مرة أخرى';
    }
  }

  /// حذف فرع
  Future<void> deleteBranch(String id) async {
    try {
      if (id.isEmpty) {
        throw 'معرف الفرع مطلوب للحذف';
      }

      await _db.collection(_collection).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting branch: $e');
      if (e is String) rethrow;
      throw 'فشل في حذف الفرع. الرجاء المحاولة مرة أخرى';
    }
  }

  /// Stream للحصول على قائمة الفروع بشكل مباشر
  Stream<List<BranchModel>> watchBranches(String companyId) {
    return _db
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BranchModel.fromFirestore(doc))
            .toList());
  }

  /// التحقق من صحة بيانات الفرع
  void _validateBranchData(BranchModel branch) {
    if (branch.companyId.isEmpty) {
      throw 'معرف الشركة مطلوب';
    }
    if (branch.name.trim().isEmpty) {
      throw 'اسم الفرع مطلوب';
    }
    if (branch.address.trim().isEmpty) {
      throw 'عنوان الفرع مطلوب';
    }
    if (branch.phone.trim().isEmpty) {
      throw 'رقم هاتف الفرع مطلوب';
    }
  }
}
