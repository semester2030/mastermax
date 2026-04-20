import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import '../config/video_upload_config.dart';
import 'cloudflare_stream_service.dart';

/// خدمة للعثور على الفيديوهات المتبقية (orphaned videos)
/// الفيديوهات التي موجودة في Firestore لكن الملفات غير موجودة
class FindOrphanedVideosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'spotlight_videos';
  final Logger _logger = Logger();

  /// العثور على جميع الفيديوهات في Firestore
  Future<List<VideoRecord>> findAllVideosInFirestore() async {
    try {
      _logger.d('🔍 Searching for all videos in Firestore...');
      
      final snapshot = await _firestore.collection(_collection).get();
      
      final List<VideoRecord> videos = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        videos.add(VideoRecord(
          id: doc.id,
          title: data['title'] as String? ?? 'بدون عنوان',
          type: data['type'] as String? ?? 'unknown',
          url: data['url'] as String? ?? '',
          uploadSource: data['uploadSource'] as String? ?? 'unknown',
          cloudflareVideoId: data['cloudflareVideoId'] as String?,
          userId: data['userId'] as String? ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          thumbnail: data['thumbnail'] as String?,
        ));
      }
      
      _logger.d('✅ Found ${videos.length} videos in Firestore');
      return videos;
    } catch (e) {
      _logger.e('Error finding videos in Firestore: $e');
      rethrow;
    }
  }

  /// التحقق من وجود الفيديو في Cloudflare
  Future<bool> checkVideoExistsInCloudflare(String cloudflareVideoId) async {
    try {
      final cloudflareService = await CloudflareStreamService.fromConfig();
      if (cloudflareService == null) {
        return false;
      }
      
      final videoInfo = await cloudflareService.getVideoInfo(cloudflareVideoId);
      return videoInfo != null;
    } catch (e) {
      _logger.w('Error checking Cloudflare video: $e');
      return false;
    }
  }

  /// التحقق من وجود الفيديو في Firebase Storage
  Future<bool> checkVideoExistsInFirebaseStorage(String url) async {
    try {
      if (!url.contains('firebasestorage.googleapis.com')) {
        return false;
      }
      
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.isEmpty) return false;
      
      final pathIndex = pathSegments.indexOf('o');
      if (pathIndex == -1 || pathIndex >= pathSegments.length - 1) return false;
      
      final filePath = pathSegments.sublist(pathIndex + 1).join('/');
      final decodedPath = Uri.decodeComponent(filePath);
      
      try {
        final ref = _storage.ref(decodedPath);
        await ref.getMetadata(); // محاولة جلب metadata - إذا فشل، الملف غير موجود
        return true;
      } catch (e) {
        return false; // الملف غير موجود
      }
    } catch (e) {
      _logger.w('Error checking Firebase Storage video: $e');
      return false;
    }
  }

  /// العثور على الفيديوهات المتبقية (orphaned)
  /// الفيديوهات التي موجودة في Firestore لكن الملفات غير موجودة
  Future<OrphanedVideosReport> findOrphanedVideos() async {
    try {
      _logger.d('🔍 Searching for orphaned videos...');
      
      final allVideos = await findAllVideosInFirestore();
      
      final List<VideoRecord> orphanedVideos = [];
      final List<VideoRecord> validVideos = [];
      final List<VideoRecord> cloudflareOnly = [];
      final List<VideoRecord> firebaseOnly = [];
      final List<VideoRecord> brokenUrls = [];
      
      for (var video in allVideos) {
        bool existsInCloudflare = false;
        bool existsInFirebase = false;
        bool hasValidUrl = false;
        
        // التحقق من Cloudflare
        if (video.uploadSource == 'cloudflare' && video.cloudflareVideoId != null) {
          existsInCloudflare = await checkVideoExistsInCloudflare(video.cloudflareVideoId!);
          if (existsInCloudflare) {
            hasValidUrl = true;
          }
        }
        
        // التحقق من Firebase Storage
        if (video.url.contains('firebasestorage.googleapis.com')) {
          existsInFirebase = await checkVideoExistsInFirebaseStorage(video.url);
          if (existsInFirebase) {
            hasValidUrl = true;
          }
        } else if (video.url.contains('cloudflarestream.com') || video.url.contains('.m3u8')) {
          // URL من Cloudflare - نعتبره صحيح إذا كان uploadSource = cloudflare
          if (video.uploadSource == 'cloudflare') {
            hasValidUrl = true;
          }
        }
        
        // تصنيف الفيديو
        if (!hasValidUrl && video.url.isEmpty) {
          brokenUrls.add(video);
          orphanedVideos.add(video);
        } else if (!hasValidUrl) {
          orphanedVideos.add(video);
        } else if (existsInCloudflare && !existsInFirebase) {
          cloudflareOnly.add(video);
          validVideos.add(video);
        } else if (existsInFirebase && !existsInCloudflare) {
          firebaseOnly.add(video);
          validVideos.add(video);
        } else {
          validVideos.add(video);
        }
      }
      
      return OrphanedVideosReport(
        total: allVideos.length,
        valid: validVideos.length,
        orphaned: orphanedVideos.length,
        cloudflareOnly: cloudflareOnly.length,
        firebaseOnly: firebaseOnly.length,
        brokenUrls: brokenUrls.length,
        orphanedVideos: orphanedVideos,
        validVideos: validVideos,
        cloudflareOnlyVideos: cloudflareOnly,
        firebaseOnlyVideos: firebaseOnly,
        brokenUrlVideos: brokenUrls,
      );
    } catch (e) {
      _logger.e('Error finding orphaned videos: $e');
      rethrow;
    }
  }

  /// حذف الفيديوهات المتبقية من Firestore
  Future<DeleteOrphanedResult> deleteOrphanedVideos({bool dryRun = true}) async {
    try {
      final report = await findOrphanedVideos();
      
      if (report.orphanedVideos.isEmpty) {
        return DeleteOrphanedResult(
          success: true,
          deleted: 0,
          message: 'لا توجد فيديوهات متبقية للحذف',
        );
      }
      
      if (dryRun) {
        return DeleteOrphanedResult(
          success: true,
          deleted: 0,
          message: 'Dry run: ${report.orphanedVideos.length} فيديو سيتم حذفها',
          orphanedVideos: report.orphanedVideos,
        );
      }
      
      int deleted = 0;
      int failed = 0;
      
      for (var video in report.orphanedVideos) {
        try {
          await _firestore.collection(_collection).doc(video.id).delete();
          deleted++;
          _logger.d('✅ Deleted orphaned video: ${video.id} - ${video.title}');
          
          // تأخير بسيط لتجنب rate limiting
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          failed++;
          _logger.w('⚠️ Failed to delete video ${video.id}: $e');
        }
      }
      
      return DeleteOrphanedResult(
        success: failed == 0,
        deleted: deleted,
        failed: failed,
        message: 'تم حذف $deleted من ${report.orphanedVideos.length} فيديو',
      );
    } catch (e) {
      _logger.e('Error deleting orphaned videos: $e');
      return DeleteOrphanedResult(
        success: false,
        deleted: 0,
        message: 'خطأ: $e',
      );
    }
  }
}

/// سجل فيديو
class VideoRecord {
  final String id;
  final String title;
  final String type;
  final String url;
  final String uploadSource;
  final String? cloudflareVideoId;
  final String userId;
  final DateTime createdAt;
  final String? thumbnail;

  VideoRecord({
    required this.id,
    required this.title,
    required this.type,
    required this.url,
    required this.uploadSource,
    this.cloudflareVideoId,
    required this.userId,
    required this.createdAt,
    this.thumbnail,
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
  bool get isFirebase => uploadSource != 'cloudflare';
}

/// تقرير الفيديوهات المتبقية
class OrphanedVideosReport {
  final int total;
  final int valid;
  final int orphaned;
  final int cloudflareOnly;
  final int firebaseOnly;
  final int brokenUrls;
  final List<VideoRecord> orphanedVideos;
  final List<VideoRecord> validVideos;
  final List<VideoRecord> cloudflareOnlyVideos;
  final List<VideoRecord> firebaseOnlyVideos;
  final List<VideoRecord> brokenUrlVideos;

  OrphanedVideosReport({
    required this.total,
    required this.valid,
    required this.orphaned,
    required this.cloudflareOnly,
    required this.firebaseOnly,
    required this.brokenUrls,
    required this.orphanedVideos,
    required this.validVideos,
    required this.cloudflareOnlyVideos,
    required this.firebaseOnlyVideos,
    required this.brokenUrlVideos,
  });
}

/// نتيجة حذف الفيديوهات المتبقية
class DeleteOrphanedResult {
  final bool success;
  final int deleted;
  final int? failed;
  final String message;
  final List<VideoRecord>? orphanedVideos;

  DeleteOrphanedResult({
    required this.success,
    required this.deleted,
    this.failed,
    required this.message,
    this.orphanedVideos,
  });
}
