import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../models/user_type.dart';

/// خدمة رفع وإدارة وثائق التحقق
class DocumentVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();

  static const String _collection = 'verification_requests';
  static const String _storagePath = 'verification_documents';

  /// رفع ملف PDF للتحقق
  /// 
  /// [userId]: معرف المستخدم
  /// [userType]: نوع الحساب
  /// [documentFile]: ملف PDF الوثائق
  Future<VerificationResult> uploadVerificationDocument({
    required String userId,
    required UserType userType,
    required File documentFile,
  }) async {
    try {
      _logger.d('📤 Uploading verification document for user: $userId, type: $userType');

      // ✅ التحقق من نوع الملف (يجب أن يكون PDF)
      if (!documentFile.path.toLowerCase().endsWith('.pdf')) {
        return VerificationResult(
          success: false,
          error: 'يجب أن يكون الملف بصيغة PDF',
        );
      }

      // ✅ رفع الملف إلى Firebase Storage
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final storageRef = _storage.ref().child('$_storagePath/$userId/$fileName');

      _logger.d('📤 Uploading to: $_storagePath/$userId/$fileName');
      
      final uploadTask = storageRef.putFile(
        documentFile,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'userId': userId,
            'userType': userType.toString(),
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // انتظار اكتمال الرفع
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      _logger.d('✅ File uploaded successfully: $downloadUrl');

      // ✅ حفظ طلب التحقق في Firestore
      final requestData = {
        'userId': userId,
        'userType': userType.toString(),
        'documentUrl': downloadUrl,
        'fileName': fileName,
        'status': VerificationStatus.pending.statusString,
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewerId': null,
        'rejectionReason': null,
      };

      await _firestore
          .collection(_collection)
          .doc(userId)
          .set(requestData, SetOptions(merge: true));

      _logger.d('✅ Verification request saved to Firestore');

      // ✅ تحديث حالة المستخدم في users collection
      await _firestore.collection('users').doc(userId).update({
        'verificationStatus': VerificationStatus.pending.statusString,
        'verificationDocumentUrl': downloadUrl,
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
      });

      return VerificationResult(
        success: true,
        documentUrl: downloadUrl,
      );
    } catch (e, stackTrace) {
      _logger.e('❌ Error uploading verification document: $e');
      _logger.e('Stack trace: $stackTrace');
      return VerificationResult(
        success: false,
        error: 'فشل في رفع الملف: ${e.toString()}',
      );
    }
  }

  /// جلب حالة التحقق للمستخدم
  Future<VerificationStatus?> getVerificationStatus(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      final statusString = data?['status'] as String?;
      if (statusString == null) return null;

      return VerificationStatus.values.firstWhere(
        (status) => status.statusString == statusString,
        orElse: () => VerificationStatus.pending,
      );
    } catch (e) {
      _logger.e('Error getting verification status: $e');
      return null;
    }
  }

  /// جلب جميع طلبات التحقق المعلقة (للمراجعين)
  Future<List<VerificationRequest>> getPendingRequests() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: VerificationStatus.pending.statusString)
          .orderBy('submittedAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return VerificationRequest.fromMap(doc.id, data);
      }).toList();
    } catch (e) {
      _logger.e('Error getting pending requests: $e');
      return [];
    }
  }

  /// قبول طلب التحقق
  Future<bool> approveVerification({
    required String userId,
    required String reviewerId,
  }) async {
    try {
      final batch = _firestore.batch();

      // تحديث طلب التحقق
      final requestRef = _firestore.collection(_collection).doc(userId);
      batch.update(requestRef, {
        'status': VerificationStatus.approved.statusString,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewerId': reviewerId,
      });

      // تحديث حالة المستخدم
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'verificationStatus': VerificationStatus.approved.statusString,
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      _logger.d('✅ Verification approved for user: $userId');
      return true;
    } catch (e) {
      _logger.e('Error approving verification: $e');
      return false;
    }
  }

  /// رفض طلب التحقق
  Future<bool> rejectVerification({
    required String userId,
    required String reviewerId,
    required String rejectionReason,
  }) async {
    try {
      final batch = _firestore.batch();

      // تحديث طلب التحقق
      final requestRef = _firestore.collection(_collection).doc(userId);
      batch.update(requestRef, {
        'status': VerificationStatus.rejected.statusString,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewerId': reviewerId,
        'rejectionReason': rejectionReason,
      });

      // تحديث حالة المستخدم
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'verificationStatus': VerificationStatus.rejected.statusString,
        'isVerified': false,
        'rejectionReason': rejectionReason,
      });

      await batch.commit();
      _logger.d('✅ Verification rejected for user: $userId');
      return true;
    } catch (e) {
      _logger.e('Error rejecting verification: $e');
      return false;
    }
  }
}

/// حالة التحقق
enum VerificationStatus {
  pending,   // في انتظار المراجعة
  approved,  // تم القبول
  rejected,  // تم الرفض
  notRequired, // لا يحتاج تحقق
}

/// Extension لـ VerificationStatus
extension VerificationStatusExtension on VerificationStatus {
  String get statusString {
    switch (this) {
      case VerificationStatus.pending:
        return 'pending';
      case VerificationStatus.approved:
        return 'approved';
      case VerificationStatus.rejected:
        return 'rejected';
      case VerificationStatus.notRequired:
        return 'notRequired';
    }
  }

  String get arabicName {
    switch (this) {
      case VerificationStatus.pending:
        return 'في انتظار المراجعة';
      case VerificationStatus.approved:
        return 'تم التحقق';
      case VerificationStatus.rejected:
        return 'مرفوض';
      case VerificationStatus.notRequired:
        return 'لا يحتاج تحقق';
    }
  }
}

/// نتيجة رفع الوثائق
class VerificationResult {
  final bool success;
  final String? documentUrl;
  final String? error;

  VerificationResult({
    required this.success,
    this.documentUrl,
    this.error,
  });
}

/// نموذج طلب التحقق
class VerificationRequest {
  final String userId;
  final UserType userType;
  final String documentUrl;
  final String fileName;
  final VerificationStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewerId;
  final String? rejectionReason;

  VerificationRequest({
    required this.userId,
    required this.userType,
    required this.documentUrl,
    required this.fileName,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewerId,
    this.rejectionReason,
  });

  factory VerificationRequest.fromMap(String id, Map<String, dynamic> map) {
    return VerificationRequest(
      userId: id,
      userType: UserType.fromString(map['userType'] as String? ?? ''),
      documentUrl: map['documentUrl'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      status: VerificationStatus.values.firstWhere(
        (status) => status.toString() == (map['status'] as String? ?? ''),
        orElse: () => VerificationStatus.pending,
      ),
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      reviewerId: map['reviewerId'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
    );
  }
}
