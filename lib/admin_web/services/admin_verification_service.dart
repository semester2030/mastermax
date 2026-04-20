import 'package:cloud_firestore/cloud_firestore.dart';
import '../../src/features/auth/models/user_type.dart';
import 'admin_audit_log_service.dart';
import 'admin_audit_models.dart';

/// خدمة التحقق للوحة الإدارة (ويب فقط - بدون dart:io)
class AdminVerificationService {
  AdminVerificationService({
    FirebaseFirestore? firestore,
    AdminAuditLogService? auditLog,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _audit = auditLog ?? AdminAuditLogService();

  final FirebaseFirestore _firestore;
  final AdminAuditLogService _audit;
  static const String _collection = 'verification_requests';

  /// جلب طلبات التحقق المعلقة
  ///
  /// بدون [Query.orderBy] على `submittedAt` لتفادي الحاجة لفهرس مركّب في Firestore؛
  /// الترتيب يُنفَّذ محلياً.
  Future<List<AdminVerificationRequest>> getPendingRequests() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'pending')
        .get();

    final list =
        snapshot.docs.map((doc) => AdminVerificationRequest.fromFirestore(doc)).toList();
    list.sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    return list;
  }

  /// جلب كل طلبات التحقق (للسجل)
  Future<List<AdminVerificationRequest>> getAllRequests({
    String? status,
    int limit = 100,
  }) async {
    if (status != null && status.isNotEmpty) {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: status)
          .limit(500)
          .get();
      final list =
          snapshot.docs.map((doc) => AdminVerificationRequest.fromFirestore(doc)).toList();
      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      if (list.length <= limit) return list;
      return list.sublist(0, limit);
    }
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('submittedAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => AdminVerificationRequest.fromFirestore(doc)).toList();
  }

  /// قبول طلب التحقق
  Future<bool> approve({required String userId, required String reviewerId}) async {
    try {
      final batch = _firestore.batch();
      final requestRef = _firestore.collection(_collection).doc(userId);
      batch.update(requestRef, {
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewerId': reviewerId,
      });
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'verificationStatus': 'approved',
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      await _audit.log(
        action: AdminAuditAction.verificationApproved,
        targetType: AdminAuditTargetType.verificationRequest,
        targetId: userId,
        summary: 'قبول طلب التحقق وتوثيق المستخدم (المعرف: $userId)',
        metadata: {'reviewerId': reviewerId},
      );
      return true;
    } catch (_) {
      await _audit.log(
        action: AdminAuditAction.verificationApproved,
        targetType: AdminAuditTargetType.verificationRequest,
        targetId: userId,
        summary: 'فشل تنفيذ قبول طلب التحقق (المعرف: $userId)',
        outcome: AdminAuditOutcome.failure,
      );
      return false;
    }
  }

  /// رفض طلب التحقق
  Future<bool> reject({
    required String userId,
    required String reviewerId,
    required String rejectionReason,
  }) async {
    try {
      final batch = _firestore.batch();
      final requestRef = _firestore.collection(_collection).doc(userId);
      batch.update(requestRef, {
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewerId': reviewerId,
        'rejectionReason': rejectionReason,
      });
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'verificationStatus': 'rejected',
        'isVerified': false,
        'rejectionReason': rejectionReason,
      });
      await batch.commit();
      await _audit.log(
        action: AdminAuditAction.verificationRejected,
        targetType: AdminAuditTargetType.verificationRequest,
        targetId: userId,
        summary: 'رفض طلب التحقق (المعرف: $userId)',
        metadata: {
          'reviewerId': reviewerId,
          'reasonSnippet': rejectionReason.length > 200
              ? '${rejectionReason.substring(0, 199)}…'
              : rejectionReason,
        },
      );
      return true;
    } catch (_) {
      await _audit.log(
        action: AdminAuditAction.verificationRejected,
        targetType: AdminAuditTargetType.verificationRequest,
        targetId: userId,
        summary: 'فشل تنفيذ رفض طلب التحقق (المعرف: $userId)',
        outcome: AdminAuditOutcome.failure,
      );
      return false;
    }
  }
}

/// نموذج طلب تحقق (ويب)
class AdminVerificationRequest {
  final String userId;
  final UserType userType;
  final String documentUrl;
  final String fileName;
  final String status; // pending, approved, rejected
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewerId;
  final String? rejectionReason;

  AdminVerificationRequest({
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

  factory AdminVerificationRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    final id = doc.id;
    return AdminVerificationRequest(
      userId: id,
      userType: UserType.fromString(map['userType'] as String? ?? ''),
      documentUrl: map['documentUrl'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      reviewerId: map['reviewerId'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
