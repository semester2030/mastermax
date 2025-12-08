import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_features.dart';

class UserFeaturesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'user_features';

  // إنشاء أو تحديث مميزات المستخدم
  Future<void> setUserFeatures(UserFeatures features) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(features.userId)
          .set(features.toFirestore());
    } catch (e) {
      throw Exception('فشل في حفظ مميزات المستخدم: $e');
    }
  }

  // الحصول على مميزات المستخدم
  Future<UserFeatures?> getUserFeatures(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        return UserFeatures.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('فشل في جلب مميزات المستخدم: $e');
    }
  }

  // تحديث نوع المستخدم
  Future<void> updateUserType(String userId, UserType newType) async {
    try {
      final features = await getUserFeatures(userId);
      if (features != null) {
        final updatedFeatures = features.copyWith(
          userType: newType,
          features: UserTypeFeatures.getFeatures(newType),
          updatedAt: DateTime.now(),
        );
        await setUserFeatures(updatedFeatures);
      } else {
        final newFeatures = UserFeatures(
          userId: userId,
          userType: newType,
          features: UserTypeFeatures.getFeatures(newType),
          extraFields: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await setUserFeatures(newFeatures);
      }
    } catch (e) {
      throw Exception('فشل في تحديث نوع المستخدم: $e');
    }
  }

  // تحديث المميزات المخصصة
  Future<void> updateCustomFeatures(String userId, List<String> newFeatures) async {
    try {
      final features = await getUserFeatures(userId);
      if (features != null) {
        final updatedFeatures = features.copyWith(
          features: newFeatures,
          updatedAt: DateTime.now(),
        );
        await setUserFeatures(updatedFeatures);
      }
    } catch (e) {
      throw Exception('فشل في تحديث المميزات المخصصة: $e');
    }
  }

  // إضافة حقول إضافية
  Future<void> updateExtraFields(String userId, Map<String, dynamic> fields) async {
    try {
      final features = await getUserFeatures(userId);
      if (features != null) {
        final updatedExtraFields = {...features.extraFields, ...fields};
        final updatedFeatures = features.copyWith(
          extraFields: updatedExtraFields,
          updatedAt: DateTime.now(),
        );
        await setUserFeatures(updatedFeatures);
      }
    } catch (e) {
      throw Exception('فشل في تحديث الحقول الإضافية: $e');
    }
  }

  // حذف مميزات المستخدم
  Future<void> deleteUserFeatures(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).delete();
    } catch (e) {
      throw Exception('فشل في حذف مميزات المستخدم: $e');
    }
  }

  // مراقبة تغييرات مميزات المستخدم
  Stream<UserFeatures?> watchUserFeatures(String userId) {
    return _firestore
        .collection(_collection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserFeatures.fromFirestore(doc) : null);
  }
} 