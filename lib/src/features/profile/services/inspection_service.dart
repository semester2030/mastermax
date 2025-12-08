import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/inspection_model.dart';

class InspectionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Inspection>> getInspections() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final snapshot = await _firestore
          .collection('inspections')
          .where('userId', isEqualTo: user.uid)
          .get();

      return snapshot.docs
          .map((doc) => Inspection.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('فشل في جلب المعاينات: $e');
    }
  }

  Future<Inspection> createInspection(Inspection inspection) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final docRef = await _firestore.collection('inspections').add({
        ...inspection.toJson(),
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final doc = await docRef.get();
      return Inspection.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      throw Exception('فشل في إنشاء المعاينة: $e');
    }
  }

  Future<void> updateInspection(String id, Inspection inspection) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      await _firestore.collection('inspections').doc(id).update({
        ...inspection.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('فشل في تحديث المعاينة: $e');
    }
  }

  Future<void> deleteInspection(String id) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      await _firestore.collection('inspections').doc(id).delete();
    } catch (e) {
      throw Exception('فشل في حذف المعاينة: $e');
    }
  }

  Future<List<Inspection>> getUpcomingInspections() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('inspections')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: now)
          .orderBy('date')
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => Inspection.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('فشل في جلب المعاينات القادمة: $e');
    }
  }

  Future<void> updateInspectionStatus(String id, String status) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      await _firestore.collection('inspections').doc(id).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('فشل في تحديث حالة المعاينة: $e');
    }
  }
} 