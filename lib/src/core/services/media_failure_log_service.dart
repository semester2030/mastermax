import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// تسجيل فشل رفع فيديو/صورة/صورة مصغّرة في Firestore لعرضه في لوحة الإدارة.
/// لا يرمي للأعلى حتى لا يكسر مسار الرفع للمستخدم.
class MediaFailureLogService {
  MediaFailureLogService._();

  static const String collectionName = 'media_upload_failures';

  static Future<void> log({
    required String mediaKind,
    required String context,
    required String errorMessage,
    String? detail,
    String? listingId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final trimmed = errorMessage.trim();
      final msg = trimmed.length > 800 ? '${trimmed.substring(0, 800)}…' : trimmed;
      final det = detail?.trim();
      final detSafe = det == null || det.isEmpty
          ? null
          : (det.length > 1500 ? '${det.substring(0, 1500)}…' : det);

      await FirebaseFirestore.instance.collection(collectionName).add({
        'userId': user?.uid ?? '',
        'email': user?.email ?? '',
        'mediaKind': mediaKind,
        'context': context,
        'errorMessage': msg,
        'detail': detSafe,
        'listingId': listingId,
        'platform': kIsWeb ? 'web' : 'mobile',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('MediaFailureLogService: $e\n$st');
    }
  }
}
