import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// حذف الحساب والبيانات المرتبطة به في Firestore ثم حذف مستخدم Firebase Auth.
/// يتطلب إعادة مصادقة بكلمة المرور قبل الاستدعاء (يُنفَّذ من الواجهة).
class AccountDeletionService {
  AccountDeletionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// إعادة المصادقة ثم حذف البيانات وحساب المصادقة.
  Future<void> deleteAccountWithPassword(String password) async {
    final trimmed = password.trim();
    if (trimmed.isEmpty) {
      throw Exception('أدخل كلمة المرور للمتابعة.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('لا يوجد مستخدم مسجّل. سجّل الدخول ثم أعد المحاولة.');
    }

    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      throw Exception(
        'حذف الحساب متاح حالياً للحسابات المسجّلة بالبريد وكلمة المرور.',
      );
    }

    try {
      final credential =
          EmailAuthProvider.credential(email: email, password: trimmed);
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } catch (e) {
      throw Exception('فشل التحقق من كلمة المرور: $e');
    }

    final uid = user.uid;

    try {
      await _deleteUserOwnedFirestoreData(uid);
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      throw Exception('تعذر حذف بيانات الحساب من الخادم: $e');
    }

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    }

    try {
      await _auth.signOut();
    } catch (_) {
      // الجلسة قد تكون منتهية بعد الحذف
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة.';
      case 'invalid-credential':
      case 'user-mismatch':
        return 'بيانات الدخول غير صحيحة. تحقق من كلمة المرور.';
      case 'requires-recent-login':
        return 'انتهت صلاحية الجلسة الأمنية. سجّل الخروج ثم أعد تسجيل الدخول وحاول الحذف مرة أخرى.';
      case 'network-request-failed':
        return 'خطأ في الاتصال. تحقق من الإنترنت وحاول مرة أخرى.';
      default:
        return 'تعذر إكمال العملية (${e.code}).';
    }
  }

  Future<void> _deleteUserOwnedFirestoreData(String uid) async {
    await _deletePropertiesWithHistory(uid);
    await _deleteQueryDocs(
      _firestore.collection('cars'),
      field: 'sellerId',
      value: uid,
    );
    await _deleteQueryDocs(
      _firestore.collection('favorites'),
      field: 'userId',
      value: uid,
    );
    await _deleteQueryDocs(
      _firestore.collection('support_tickets'),
      field: 'userId',
      value: uid,
    );
    await _deleteQueryDocs(
      _firestore.collection('bank_transfers'),
      field: 'userId',
      value: uid,
    );
    await _deleteQueryDocs(
      _firestore.collection('spotlight_videos'),
      field: 'sellerId',
      value: uid,
    );
    await _deletePropertyReviewsForUser(uid);
    await _deleteQueryDocs(
      _firestore.collection('sales'),
      field: 'sellerId',
      value: uid,
    );
    await _deleteQueryDocs(
      _firestore.collection('customers'),
      field: 'sellerId',
      value: uid,
    );
    await _deleteQueryDocs(
      _firestore.collection('real_estate_customers'),
      field: 'companyId',
      value: uid,
    );
    await _deleteQueryDocs(
      _firestore.collection('branches'),
      field: 'companyId',
      value: uid,
    );
    await _deleteRentalsForOwner(uid);
    await _safeDeleteDoc(_firestore.collection('subscriptions').doc(uid));
    await _safeDeleteDoc(_firestore.collection('user_features').doc(uid));
  }

  Future<void> _deletePropertiesWithHistory(String uid) async {
    const batchSize = 15;
    while (true) {
      final snap = await _firestore
          .collection('properties')
          .where('ownerId', isEqualTo: uid)
          .limit(batchSize)
          .get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        try {
          final hist =
              await doc.reference.collection('status_history').limit(50).get();
          for (final h in hist.docs) {
            try {
              await h.reference.delete();
            } catch (e) {
              debugPrint('AccountDeletion: status_history ${h.id}: $e');
            }
          }
          await doc.reference.delete();
        } catch (e) {
          debugPrint('AccountDeletion: property ${doc.id}: $e');
        }
      }
      if (snap.docs.length < batchSize) break;
    }
  }

  Future<void> _deleteRentalsForOwner(String uid) async {
    const batchSize = 20;
    while (true) {
      final snap = await _firestore
          .collection('rentals')
          .where('ownerId', isEqualTo: uid)
          .limit(batchSize)
          .get();
      if (snap.docs.isEmpty) break;
      for (final doc in snap.docs) {
        try {
          await doc.reference.delete();
        } catch (e) {
          debugPrint('AccountDeletion: rental ${doc.id}: $e');
        }
      }
      if (snap.docs.length < batchSize) break;
    }
  }

  Future<void> _deletePropertyReviewsForUser(String uid) async {
    const batchSize = 20;
    while (true) {
      final snap = await _firestore
          .collection('property_reviews')
          .where('userId', isEqualTo: uid)
          .limit(batchSize)
          .get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        try {
          final replies =
              await doc.reference.collection('replies').limit(50).get();
          for (final r in replies.docs) {
            try {
              await r.reference.delete();
            } catch (e) {
              debugPrint('AccountDeletion: reply ${r.id}: $e');
            }
          }
          await doc.reference.delete();
        } catch (e) {
          debugPrint('AccountDeletion: review ${doc.id}: $e');
        }
      }
      if (snap.docs.length < batchSize) break;
    }
  }

  Future<void> _deleteQueryDocs(
    CollectionReference<Map<String, dynamic>> collection, {
    required String field,
    required String value,
  }) async {
    const batchSize = 25;
    while (true) {
      final snap =
          await collection.where(field, isEqualTo: value).limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      for (final doc in snap.docs) {
        try {
          await doc.reference.delete();
        } catch (e) {
          debugPrint('AccountDeletion: ${collection.path}/${doc.id}: $e');
        }
      }
      if (snap.docs.length < batchSize) break;
    }
  }

  Future<void> _safeDeleteDoc(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      final doc = await ref.get();
      if (doc.exists) {
        await ref.delete();
      }
    } catch (e) {
      debugPrint('AccountDeletion: doc ${ref.path}: $e');
    }
  }
}
