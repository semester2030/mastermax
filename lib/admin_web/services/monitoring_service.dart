import 'package:cloud_firestore/cloud_firestore.dart';

/// تجميعات وقراءات لوحة المراقبة (أدمن فقط — حسب قواعد Firestore).
class MonitoringService {
  MonitoringService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _videos = 'spotlight_videos';
  static const String _failures = 'media_upload_failures';
  static const String _verification = 'verification_requests';
  static const String _sessions = 'app_sessions';

  Future<int> countCollection(String name) async {
    final snap = await _db.collection(name).count().get();
    return snap.count ?? 0;
  }

  Future<int> countPendingVerification() async {
    final snap = await _db
        .collection(_verification)
        .where('status', isEqualTo: 'pending')
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// عدد فشل الرفع خلال آخر 24 ساعة (من عيّنة حديثة لتفادي فهارس مركّبة).
  Future<int> countFailuresLast24Hours() async {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final rows = await recentFailures(limit: 200);
    return rows.where((r) => r.createdAt != null && r.createdAt!.isAfter(since)).length;
  }

  /// أعلى N فيديو حسب المشاهدات.
  Future<List<VideoEngagementRow>> topVideosByViews({int limit = 40}) async {
    final q = await _db
        .collection(_videos)
        .orderBy('viewsCount', descending: true)
        .limit(limit)
        .get();
    return q.docs.map(VideoEngagementRow.fromDoc).toList();
  }

  /// أقل N فيديو حسب المشاهدات (صفر أولاً).
  Future<List<VideoEngagementRow>> leastVideosByViews({int limit = 40}) async {
    final q = await _db
        .collection(_videos)
        .orderBy('viewsCount', descending: false)
        .limit(limit)
        .get();
    return q.docs.map(VideoEngagementRow.fromDoc).toList();
  }

  Future<List<MediaFailureRow>> recentFailures({int limit = 80}) async {
    final q = await _db
        .collection(_failures)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return q.docs.map(MediaFailureRow.fromDoc).toList();
  }

  /// تجميع حسب البائع/الشركة (من عيّنة حديثة للفيديوهات).
  Future<List<SellerRollupRow>> sellerRollups({int videoSampleLimit = 350}) async {
    final q = await _db
        .collection(_videos)
        .orderBy('createdAt', descending: true)
        .limit(videoSampleLimit)
        .get();

    final map = <String, SellerRollupRow>{};
    for (final doc in q.docs) {
      final d = doc.data();
      final sid = (d['sellerId'] ?? d['userId'] ?? '').toString().trim();
      if (sid.isEmpty) continue;
      final name = (d['sellerName'] ?? d['name'] ?? '—').toString();
      final views = (d['viewsCount'] as num?)?.toInt() ?? 0;
      final existing = map[sid];
      if (existing == null) {
        map[sid] = SellerRollupRow(
          sellerId: sid,
          sellerName: name.isEmpty ? '—' : name,
          videoCount: 1,
          totalViews: views,
        );
      } else {
        map[sid] = SellerRollupRow(
          sellerId: sid,
          sellerName: name.isNotEmpty && name != '—' ? name : existing.sellerName,
          videoCount: existing.videoCount + 1,
          totalViews: existing.totalViews + views,
        );
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.totalViews.compareTo(a.totalViews));
    return list;
  }

  Future<List<AppSessionRow>> recentSessions({int limit = 120}) async {
    final q = await _db
        .collection(_sessions)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return q.docs.map(AppSessionRow.fromDoc).toList();
  }

  /// تحديث مباشر لآخر الجلسات (لوحة الإدمن فقط).
  Stream<List<AppSessionRow>> watchRecentSessions({int limit = 200}) {
    return _db
        .collection(_sessions)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AppSessionRow.fromDoc).toList());
  }

  /// جلسات بدأت خلال آخر 24 ساعة (من عيّنة).
  int countSessionsStartedLast24Hours(List<AppSessionRow> sample) {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    return sample.where((s) => s.startedAt != null && s.startedAt!.isAfter(since)).length;
  }

  /// متوسط مدة الجلسة (ثوانٍ) للجلسات المُغلقة في العيّنة.
  int averageForegroundSeconds(List<AppSessionRow> sample) {
    final withDuration = sample.where((s) => s.foregroundSeconds > 0).toList();
    if (withDuration.isEmpty) return 0;
    final sum = withDuration.fold<int>(0, (a, s) => a + s.foregroundSeconds);
    return (sum / withDuration.length).round();
  }
}

class VideoEngagementRow {
  VideoEngagementRow({
    required this.id,
    required this.title,
    required this.sellerName,
    required this.sellerId,
    required this.type,
    required this.viewsCount,
    required this.likesCount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String sellerName;
  final String sellerId;
  final String type;
  final int viewsCount;
  final int likesCount;
  final DateTime? createdAt;

  factory VideoEngagementRow.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return VideoEngagementRow(
      id: doc.id,
      title: (d['title'] ?? 'بدون عنوان').toString(),
      sellerName: (d['sellerName'] ?? '—').toString(),
      sellerId: (d['sellerId'] ?? d['userId'] ?? '').toString(),
      type: (d['type'] ?? '—').toString(),
      viewsCount: (d['viewsCount'] as num?)?.toInt() ?? 0,
      likesCount: (d['likesCount'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class MediaFailureRow {
  MediaFailureRow({
    required this.id,
    required this.mediaKind,
    required this.context,
    required this.errorMessage,
    required this.detail,
    required this.userId,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String mediaKind;
  final String context;
  final String errorMessage;
  final String? detail;
  final String userId;
  final String email;
  final DateTime? createdAt;

  factory MediaFailureRow.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return MediaFailureRow(
      id: doc.id,
      mediaKind: (d['mediaKind'] ?? '—').toString(),
      context: (d['context'] ?? '—').toString(),
      errorMessage: (d['errorMessage'] ?? '').toString(),
      detail: d['detail'] as String?,
      userId: (d['userId'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class SellerRollupRow {
  SellerRollupRow({
    required this.sellerId,
    required this.sellerName,
    required this.videoCount,
    required this.totalViews,
  });

  final String sellerId;
  final String sellerName;
  final int videoCount;
  final int totalViews;
}

class AppSessionRow {
  AppSessionRow({
    required this.id,
    required this.userId,
    required this.email,
    required this.platform,
    required this.foregroundSeconds,
    required this.startedAt,
    required this.endedAt,
  });

  final String id;
  final String userId;
  final String email;
  final String platform;
  final int foregroundSeconds;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isOpen => endedAt == null;

  factory AppSessionRow.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AppSessionRow(
      id: doc.id,
      userId: (d['userId'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      platform: (d['platform'] ?? '—').toString(),
      foregroundSeconds: (d['foregroundSeconds'] as num?)?.toInt() ?? 0,
      startedAt: (d['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (d['endedAt'] as Timestamp?)?.toDate(),
    );
  }
}
