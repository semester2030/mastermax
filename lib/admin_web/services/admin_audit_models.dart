import 'package:cloud_firestore/cloud_firestore.dart';

/// مفاتيح إجراءات ثابتة (لا تغيّر القيم القديمة في السجلات — أضف مفاتيحاً جديدة فقط).
abstract class AdminAuditAction {
  static const String verificationApproved = 'verification.approved';
  static const String verificationRejected = 'verification.rejected';
  static const String auditExported = 'audit.exported';
}

abstract class AdminAuditOutcome {
  static const String success = 'success';
  static const String failure = 'failure';
}

abstract class AdminAuditTargetType {
  static const String verificationRequest = 'verification_request';
  static const String auditLog = 'admin_audit_log';
}

class AdminAuditLogRow {
  AdminAuditLogRow({
    required this.id,
    required this.actorUid,
    required this.actorEmail,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.summary,
    required this.outcome,
    required this.source,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final String actorUid;
  final String actorEmail;
  final String action;
  final String targetType;
  final String targetId;
  final String summary;
  final String outcome;
  final String source;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  bool get isFailure => outcome == AdminAuditOutcome.failure;

  factory AdminAuditLogRow.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final meta = d['metadata'];
    return AdminAuditLogRow(
      id: doc.id,
      actorUid: (d['actorUid'] ?? '').toString(),
      actorEmail: (d['actorEmail'] ?? '').toString(),
      action: (d['action'] ?? '').toString(),
      targetType: (d['targetType'] ?? '').toString(),
      targetId: (d['targetId'] ?? '').toString(),
      summary: (d['summary'] ?? '').toString(),
      outcome: (d['outcome'] ?? AdminAuditOutcome.success).toString(),
      source: (d['source'] ?? '').toString(),
      metadata: meta is Map<String, dynamic> ? Map<String, dynamic>.from(meta) : {},
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
