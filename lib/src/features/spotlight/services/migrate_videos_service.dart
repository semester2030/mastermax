import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../models/video_model.dart';
import 'cloudflare_stream_service.dart';
import '../config/video_upload_config.dart';

/// خدمة نقل الفيديوهات من Firebase Storage إلى Cloudflare Stream
/// 
/// هذا السكربت يقوم بـ:
/// 1. جلب جميع الفيديوهات من Firestore
/// 2. تحميل الفيديوهات من Firebase Storage
/// 3. رفعها إلى Cloudflare Stream
/// 4. تحديث URLs في Firestore
/// 5. حذف الفيديوهات من Firebase Storage (اختياري)
class MigrateVideosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'spotlight_videos';
  final Logger _logger = Logger();
  
  CloudflareStreamService? _cloudflareService;
  
  /// تهيئة الخدمة
  Future<bool> initialize() async {
    try {
      // التحقق من Cloudflare configuration
      final isConfigured = await VideoUploadConfig.isCloudflareConfigured();
      if (!isConfigured) {
        _logger.e('Cloudflare not configured. Please configure first.');
        return false;
      }
      
      _cloudflareService = await CloudflareStreamService.fromConfig();
      if (_cloudflareService == null) {
        _logger.e('Failed to initialize Cloudflare service');
        return false;
      }
      
      _logger.d('✅ MigrateVideosService initialized successfully');
      return true;
    } catch (e) {
      _logger.e('Error initializing MigrateVideosService: $e');
      return false;
    }
  }
  
  /// جلب جميع الفيديوهات من Firestore
  Future<List<VideoMigrationItem>> getAllVideos() async {
    try {
      _logger.d('📥 Fetching all videos from Firestore...');
      
      final snapshot = await _firestore
          .collection(_collection)
          .get();
      
      final videos = <VideoMigrationItem>[];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // تخطي الفيديوهات التي رُفعت بالفعل إلى Cloudflare
        final uploadSource = data['uploadSource'] as String?;
        if (uploadSource == 'cloudflare') {
          _logger.d('⏭️ Skipping video ${doc.id} - already in Cloudflare');
          continue;
        }
        
        // التحقق من أن URL من Firebase Storage
        final url = data['url'] as String?;
        if (url == null || !url.contains('firebasestorage.googleapis.com')) {
          _logger.w('⚠️ Skipping video ${doc.id} - invalid URL: $url');
          continue;
        }
        
        try {
          final video = VideoModel.fromMap({
            'id': doc.id,
            ...data,
          });
          
          videos.add(VideoMigrationItem(
            videoId: doc.id,
            video: video,
            firebaseUrl: url,
            userId: data['userId'] as String? ?? '',
          ));
        } catch (e) {
          _logger.w('⚠️ Error parsing video ${doc.id}: $e');
          continue;
        }
      }
      
      _logger.d('✅ Found ${videos.length} videos to migrate');
      return videos;
    } catch (e) {
      _logger.e('Error fetching videos: $e');
      return [];
    }
  }
  
  /// نقل فيديو واحد من Firebase إلى Cloudflare
  Future<MigrationResult> migrateVideo(VideoMigrationItem item) async {
    try {
      _logger.d('🔄 Migrating video: ${item.videoId}');
      
      // 1. تحميل الفيديو من Firebase Storage
      final tempFile = await _downloadFromFirebase(item.firebaseUrl);
      if (tempFile == null) {
        return MigrationResult(
          success: false,
          videoId: item.videoId,
          error: 'Failed to download from Firebase',
        );
      }
      
      try {
        // 2. رفع الفيديو إلى Cloudflare
        final cloudflareResult = await _cloudflareService!.uploadVideo(
          videoFile: tempFile,
          title: item.video.title,
        );
        
        if (!cloudflareResult.success || cloudflareResult.videoId == null) {
          return MigrationResult(
            success: false,
            videoId: item.videoId,
            error: cloudflareResult.error ?? 'Unknown error',
          );
        }
        
        // 3. تحديث Firestore بالـ URL الجديد
        await _updateFirestore(
          videoId: item.videoId,
          cloudflareVideoId: cloudflareResult.videoId!,
          playbackUrl: cloudflareResult.playbackUrl!,
          thumbnailUrl: cloudflareResult.thumbnailUrl,
        );
        
        _logger.d('✅ Successfully migrated video: ${item.videoId}');
        
        return MigrationResult(
          success: true,
          videoId: item.videoId,
          cloudflareVideoId: cloudflareResult.videoId,
          playbackUrl: cloudflareResult.playbackUrl,
        );
      } finally {
        // 4. حذف الملف المؤقت
        try {
          await tempFile.delete();
        } catch (e) {
          _logger.w('Failed to delete temp file: $e');
        }
      }
    } catch (e) {
      _logger.e('Error migrating video ${item.videoId}: $e');
      return MigrationResult(
        success: false,
        videoId: item.videoId,
        error: e.toString(),
      );
    }
  }
  
  /// نقل جميع الفيديوهات
  Future<MigrationSummary> migrateAllVideos({
    bool deleteFromFirebase = false,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      _logger.d('🚀 Starting migration of all videos...');
      
      final videos = await getAllVideos();
      if (videos.isEmpty) {
        _logger.w('No videos to migrate');
        return MigrationSummary(
          total: 0,
          successful: 0,
          failed: 0,
          results: [],
        );
      }
      
      final results = <MigrationResult>[];
      int successful = 0;
      int failed = 0;
      
      for (int i = 0; i < videos.length; i++) {
        final item = videos[i];
        
        // تحديث التقدم
        onProgress?.call(i + 1, videos.length);
        
        final result = await migrateVideo(item);
        results.add(result);
        
        if (result.success) {
          successful++;
          
          // حذف من Firebase Storage إذا طُلب
          if (deleteFromFirebase) {
            await _deleteFromFirebase(item.firebaseUrl);
          }
        } else {
          failed++;
        }
        
        // تأخير قصير لتجنب rate limiting
        await Future.delayed(const Duration(seconds: 1));
      }
      
      final summary = MigrationSummary(
        total: videos.length,
        successful: successful,
        failed: failed,
        results: results,
      );
      
      _logger.d('✅ Migration completed: $successful successful, $failed failed');
      return summary;
    } catch (e) {
      _logger.e('Error in migrateAllVideos: $e');
      rethrow;
    }
  }
  
  /// تحميل فيديو من Firebase Storage
  Future<File?> _downloadFromFirebase(String url) async {
    try {
      _logger.d('📥 Downloading from Firebase: $url');
      
      // استخراج مسار الملف من URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.isEmpty) {
        _logger.e('Invalid Firebase URL: $url');
        return null;
      }
      
      // مسار Firebase Storage: /v0/b/{bucket}/o/{path}
      final pathIndex = pathSegments.indexOf('o');
      if (pathIndex == -1 || pathIndex >= pathSegments.length - 1) {
        _logger.e('Could not extract path from URL: $url');
        return null;
      }
      
      final filePath = pathSegments.sublist(pathIndex + 1).join('/');
      final decodedPath = Uri.decodeComponent(filePath);
      
      // الحصول على reference
      final ref = _storage.ref(decodedPath);
      
      // إنشاء ملف مؤقت
      final tempDir = Directory.systemTemp;
      final fileName = decodedPath.split('/').last;
      final tempFile = File('${tempDir.path}/$fileName');
      
      // تحميل الملف
      await ref.writeToFile(tempFile);
      
      _logger.d('✅ Downloaded to: ${tempFile.path}');
      return tempFile;
    } catch (e) {
      _logger.e('Error downloading from Firebase: $e');
      return null;
    }
  }
  
  /// تحديث Firestore بالـ URL الجديد
  Future<void> _updateFirestore({
    required String videoId,
    required String cloudflareVideoId,
    required String playbackUrl,
    String? thumbnailUrl,
  }) async {
    try {
      await _firestore.collection(_collection).doc(videoId).update({
        'url': playbackUrl,
        'uploadSource': 'cloudflare',
        'cloudflareVideoId': cloudflareVideoId,
        'migratedAt': FieldValue.serverTimestamp(),
        if (thumbnailUrl != null) 'thumbnail': thumbnailUrl,
      });
      
      _logger.d('✅ Updated Firestore for video: $videoId');
    } catch (e) {
      _logger.e('Error updating Firestore: $e');
      rethrow;
    }
  }
  
  /// حذف فيديو من Firebase Storage
  Future<void> _deleteFromFirebase(String url) async {
    try {
      _logger.d('🗑️ Deleting from Firebase: $url');
      
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.isEmpty) return;
      
      final pathIndex = pathSegments.indexOf('o');
      if (pathIndex == -1 || pathIndex >= pathSegments.length - 1) return;
      
      final filePath = pathSegments.sublist(pathIndex + 1).join('/');
      final decodedPath = Uri.decodeComponent(filePath);
      
      final ref = _storage.ref(decodedPath);
      await ref.delete();
      
      _logger.d('✅ Deleted from Firebase: $decodedPath');
    } catch (e) {
      _logger.w('Failed to delete from Firebase: $e');
      // لا نرمي الخطأ - الحذف اختياري
    }
  }
}

/// عنصر فيديو للهجرة
class VideoMigrationItem {
  final String videoId;
  final VideoModel video;
  final String firebaseUrl;
  final String userId;
  
  VideoMigrationItem({
    required this.videoId,
    required this.video,
    required this.firebaseUrl,
    required this.userId,
  });
}

/// نتيجة نقل فيديو واحد
class MigrationResult {
  final bool success;
  final String videoId;
  final String? cloudflareVideoId;
  final String? playbackUrl;
  final String? error;
  
  MigrationResult({
    required this.success,
    required this.videoId,
    this.cloudflareVideoId,
    this.playbackUrl,
    this.error,
  });
}

/// ملخص عملية النقل
class MigrationSummary {
  final int total;
  final int successful;
  final int failed;
  final List<MigrationResult> results;
  
  MigrationSummary({
    required this.total,
    required this.successful,
    required this.failed,
    required this.results,
  });
  
  double get successRate => total > 0 ? successful / total : 0.0;
}
