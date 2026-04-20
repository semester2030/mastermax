import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_audit_models.dart';

/// تسجيل إجراءات الإدارة المهمة في `admin_audit_logs`.
/// المعرف `actorUid` يُؤخذ دائماً من الجلسة الحالية — لا يُقبل من المُستدعي.
class AdminAuditLogService {
  AdminAuditLogService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const String collectionName = 'admin_audit_logs';

  static const int _maxSummary = 1900;
  static const int _maxMetaEntries = 24;
  static const int _maxMetaKeyLen = 64;
  static const int _maxMetaStrValLen = 500;

  Stream<List<AdminAuditLogRow>> watchRecent({int limit = 200}) {
    return _db
        .collection(collectionName)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(AdminAuditLogRow.fromDoc).toList());
  }

  /// تسجيل حدث. لا يُرمى استثناء للمتصل — الإجراء الأساسي (قبول/رفض…) لا يجب أن يفشل بسبب السجل.
  Future<void> log({
    required String action,
    required String targetType,
    String? targetId,
    required String summary,
    Map<String, dynamic>? metadata,
    String outcome = AdminAuditOutcome.success,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final meta = _sanitizeMetadata(metadata);
    final payload = <String, dynamic>{
      'actorUid': user.uid,
      'action': _truncate(action, 120),
      'targetType': _truncate(targetType, 80),
      'summary': _truncate(summary, _maxSummary),
      'outcome': outcome == AdminAuditOutcome.failure ? AdminAuditOutcome.failure : AdminAuditOutcome.success,
      'source': 'admin_web',
      'createdAt': FieldValue.serverTimestamp(),
    };
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      payload['actorEmail'] = _truncate(email, 320);
    }
    final tid = targetId?.trim();
    if (tid != null && tid.isNotEmpty) {
      payload['targetId'] = _truncate(tid, 200);
    }
    if (meta.isNotEmpty) {
      payload['metadata'] = meta;
    }

    try {
      await _db.collection(collectionName).add(payload);
    } catch (_) {
      // تعمّد عدم الإزعاج للمستخدم؛ فشل التدقيق يُسجَّل خارج واجهة الإدارة إن لزم لاحقاً.
    }
  }

  Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return {};
    final out = <String, dynamic>{};
    var n = 0;
    for (final e in raw.entries) {
      if (n >= _maxMetaEntries) break;
      final k = e.key.toString().trim();
      if (k.isEmpty || k.length > _maxMetaKeyLen) continue;
      final v = e.value;
      if (v == null) {
        out[k] = '';
      } else if (v is bool || v is int || v is double) {
        out[k] = v;
      } else if (v is String) {
        out[k] = _truncate(v, _maxMetaStrValLen);
      } else {
        out[k] = _truncate(v.toString(), _maxMetaStrValLen);
      }
      n++;
    }
    return out;
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max - 1)}…';
  }
}
