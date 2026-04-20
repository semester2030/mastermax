import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'cloudflare_stream_service.dart';

/// خدمة إدارية لحذف الفيديوهات (للمسؤولين)
class AdminVideoDeleteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'spotlight_videos';
  final Logger _logger = Logger();

  /// جلب جميع الفيديوهات (للعرض)
  Future<List<VideoInfo>> getAllVideos() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      
      return snapshot.docs.map((doc) {
        // ✅ تحويل صريح إلى Map<String, dynamic> مع قيمة افتراضية
        final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
        return VideoInfo(
          id: doc.id,
          title: data['title'] as String? ?? 'بدون عنوان',
          type: data['type'] as String? ?? 'unknown',
          url: data['url'] as String? ?? '',
          uploadSource: data['uploadSource'] as String? ?? 'unknown',
          cloudflareVideoId: data['cloudflareVideoId'] as String?,
          userId: data['userId'] as String? ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      _logger.e('Error fetching videos: $e');
      rethrow;
    }
  }

  /// حذف فيديو بقوة (بدون التحقق من الملكية)
  Future<DeleteResult> forceDeleteVideo(String videoId) async {
    try {
      _logger.d('🗑️ Force deleting video: $videoId');

      // جلب بيانات الفيديو
      final videoDoc = await _firestore.collection(_collection).doc(videoId).get();
      if (!videoDoc.exists) {
        return DeleteResult(
          success: false,
          error: 'الفيديو غير موجود في Firestore',
        );
      }

      final videoData = videoDoc.data()!;
      final uploadSource = videoData['uploadSource'] as String?;
      final cloudflareVideoId = videoData['cloudflareVideoId'] as String?;
      final videoUrl = videoData['url'] as String?;
      final thumbnailUrl = videoData['thumbnail'] as String?;

      final List<String> deletedFrom = [];
      final List<String> errors = [];

      // 1. حذف من Cloudflare
      if (uploadSource == 'cloudflare' && cloudflareVideoId != null) {
        try {
          final cloudflareService = await CloudflareStreamService.fromConfig();
          if (cloudflareService != null) {
            await cloudflareService.deleteSpotlightVideo(spotlightDocId: videoId);
            deletedFrom.add('Cloudflare Stream');
            _logger.d('✅ Deleted from Cloudflare: $cloudflareVideoId');
          } else {
            errors.add('فشل في تهيئة خدمة Cloudflare');
          }
        } catch (e) {
          errors.add('فشل في حذف من Cloudflare: $e');
          _logger.w('Failed to delete from Cloudflare: $e');
        }
      }

      // 2. حذف من Firebase Storage (إذا كان URL من Firebase)
      if (videoUrl != null && videoUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final uri = Uri.parse(videoUrl);
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty) {
            final pathIndex = pathSegments.indexOf('o');
            if (pathIndex != -1 && pathIndex < pathSegments.length - 1) {
              final filePath = pathSegments.sublist(pathIndex + 1).join('/');
              final decodedPath = Uri.decodeComponent(filePath);
              final videoRef = _storage.ref(decodedPath);
              await videoRef.delete();
              deletedFrom.add('Firebase Storage (video)');
              _logger.d('✅ Deleted video from Firebase Storage: $decodedPath');
            }
          }
        } catch (e) {
          errors.add('فشل في حذف الفيديو من Firebase Storage: $e');
          _logger.w('Failed to delete video from Firebase Storage: $e');
        }
      }

      // 3. حذف thumbnail من Firebase Storage
      if (thumbnailUrl != null && thumbnailUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final uri = Uri.parse(thumbnailUrl);
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty) {
            final pathIndex = pathSegments.indexOf('o');
            if (pathIndex != -1 && pathIndex < pathSegments.length - 1) {
              final filePath = pathSegments.sublist(pathIndex + 1).join('/');
              final decodedPath = Uri.decodeComponent(filePath);
              final thumbRef = _storage.ref(decodedPath);
              await thumbRef.delete();
              deletedFrom.add('Firebase Storage (thumbnail)');
              _logger.d('✅ Deleted thumbnail from Firebase Storage: $decodedPath');
            }
          }
        } catch (e) {
          errors.add('فشل في حذف thumbnail من Firebase Storage: $e');
          _logger.w('Failed to delete thumbnail from Firebase Storage: $e');
        }
      }

      // 4. حذف من Firestore (الأهم - يجب أن يحدث دائماً)
      try {
        await _firestore.collection(_collection).doc(videoId).delete();
        deletedFrom.add('Firestore');
        _logger.d('✅ Deleted from Firestore: $videoId');
      } catch (e) {
        errors.add('فشل في حذف من Firestore: $e');
        _logger.e('Failed to delete from Firestore: $e');
        return DeleteResult(
          success: false,
          error: 'فشل في حذف من Firestore: $e',
          deletedFrom: deletedFrom,
          errors: errors,
        );
      }

      return DeleteResult(
        success: true,
        deletedFrom: deletedFrom,
        errors: errors.isEmpty ? null : errors,
      );
    } catch (e) {
      _logger.e('Error force deleting video: $e');
      return DeleteResult(
        success: false,
        error: 'خطأ عام: $e',
      );
    }
  }

  /// حذف عدة فيديوهات دفعة واحدة
  Future<BatchDeleteResult> deleteMultipleVideos(List<String> videoIds) async {
    final List<DeleteResult> results = [];
    
    for (final videoId in videoIds) {
      final result = await forceDeleteVideo(videoId);
      results.add(result);
      // تأخير بسيط لتجنب rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final successful = results.where((r) => r.success).length;
    final failed = results.where((r) => !r.success).length;

    return BatchDeleteResult(
      total: videoIds.length,
      successful: successful,
      failed: failed,
      results: results,
    );
  }

  /// البحث عن فيديوهات حسب العنوان أو النوع
  Future<List<VideoInfo>> searchVideos({
    String? title,
    String? type, // 'car' or 'realEstate'
  }) async {
    try {
      Query query = _firestore.collection(_collection);
      
      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }
      
      final snapshot = await query.get();
      
      var videos = snapshot.docs.map((doc) {
        // ✅ تحويل صريح إلى Map<String, dynamic> مع قيمة افتراضية
        final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
        return VideoInfo(
          id: doc.id,
          title: data['title'] as String? ?? 'بدون عنوان',
          type: data['type'] as String? ?? 'unknown',
          url: data['url'] as String? ?? '',
          uploadSource: data['uploadSource'] as String? ?? 'unknown',
          cloudflareVideoId: data['cloudflareVideoId'] as String?,
          userId: data['userId'] as String? ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      // تصفية حسب العنوان (إذا كان محدداً)
      if (title != null && title.isNotEmpty) {
        videos = videos.where((v) => 
          v.title.toLowerCase().contains(title.toLowerCase())
        ).toList();
      }

      return videos;
    } catch (e) {
      _logger.e('Error searching videos: $e');
      rethrow;
    }
  }
}

/// معلومات الفيديو
class VideoInfo {
  final String id;
  final String title;
  final String type;
  final String url;
  final String uploadSource;
  final String? cloudflareVideoId;
  final String userId;
  final DateTime createdAt;

  VideoInfo({
    required this.id,
    required this.title,
    required this.type,
    required this.url,
    required this.uploadSource,
    this.cloudflareVideoId,
    required this.userId,
    required this.createdAt,
  });

  String get typeDisplay {
    switch (type) {
      case 'car':
        return 'سيارة';
      case 'realEstate':
        return 'عقار';
      default:
        return type;
    }
  }

  bool get isCloudflare => uploadSource == 'cloudflare';
  bool get isFirebase => uploadSource != 'cloudflare' && url.contains('firebasestorage');
}

/// نتيجة الحذف
class DeleteResult {
  final bool success;
  final String? error;
  final List<String>? deletedFrom;
  final List<String>? errors;

  DeleteResult({
    required this.success,
    this.error,
    this.deletedFrom,
    this.errors,
  });
}

/// نتيجة الحذف الجماعي
class BatchDeleteResult {
  final int total;
  final int successful;
  final int failed;
  final List<DeleteResult> results;

  BatchDeleteResult({
    required this.total,
    required this.successful,
    required this.failed,
    required this.results,
  });
}
