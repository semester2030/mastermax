import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import '../config/video_upload_config.dart';
import 'cloudflare_stream_service.dart';

/// خدمة للتحقق من حالة الفيديوهات
class CheckVideosStatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'spotlight_videos';
  final Logger _logger = Logger();

  /// فحص حالة جميع الفيديوهات
  Future<VideosStatusReport> checkAllVideos() async {
    try {
      _logger.d('🔍 Checking videos status...');

      // 1. فحص Firestore
      final firestoreStatus = await _checkFirestore();

      // 2. فحص Firebase Storage
      final storageStatus = await _checkFirebaseStorage();

      // 3. فحص Cloudflare
      final cloudflareStatus = await _checkCloudflare();

      return VideosStatusReport(
        firestore: firestoreStatus,
        firebaseStorage: storageStatus,
        cloudflare: cloudflareStatus,
      );
    } catch (e) {
      _logger.e('Error checking videos status: $e');
      rethrow;
    }
  }

  /// فحص Firestore
  Future<FirestoreStatus> _checkFirestore() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();

      int total = snapshot.docs.length;
      int firebaseUrls = 0;
      int cloudflareUrls = 0;
      int brokenUrls = 0;
      int hasCloudflareId = 0;

      final brokenVideoIds = <String>[];
      final cloudflareVideoIds = <String, String>{}; // videoId -> cloudflareVideoId

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final url = data['url'] as String? ?? '';
        final uploadSource = data['uploadSource'] as String?;
        final cloudflareVideoId = data['cloudflareVideoId'] as String?;

        if (cloudflareVideoId != null) {
          hasCloudflareId++;
          cloudflareVideoIds[doc.id] = cloudflareVideoId;
        }

        if (url.isEmpty) {
          brokenUrls++;
          brokenVideoIds.add(doc.id);
        } else if (url.contains('firebasestorage.googleapis.com')) {
          firebaseUrls++;
        } else if (url.contains('cloudflarestream.com') || url.contains('.m3u8')) {
          cloudflareUrls++;
        } else {
          brokenUrls++;
          brokenVideoIds.add(doc.id);
        }
      }

      return FirestoreStatus(
        total: total,
        firebaseUrls: firebaseUrls,
        cloudflareUrls: cloudflareUrls,
        brokenUrls: brokenUrls,
        hasCloudflareId: hasCloudflareId,
        brokenVideoIds: brokenVideoIds,
        cloudflareVideoIds: cloudflareVideoIds,
      );
    } catch (e) {
      _logger.e('Error checking Firestore: $e');
      rethrow;
    }
  }

  /// فحص Firebase Storage
  Future<StorageStatus> _checkFirebaseStorage() async {
    try {
      // محاولة جلب قائمة من مجلد videos
      final listResult = await _storage.ref('videos').listAll();

      int totalFiles = 0;
      int totalSize = 0;

      for (var prefix in listResult.prefixes) {
        final prefixList = await prefix.listAll();
        totalFiles += prefixList.items.length;
        for (var item in prefixList.items) {
          final metadata = await item.getMetadata();
          totalSize += metadata.size ?? 0;
        }
      }

      totalFiles += listResult.items.length;
      for (var item in listResult.items) {
        final metadata = await item.getMetadata();
        totalSize += metadata.size ?? 0;
      }

      return StorageStatus(
        totalFiles: totalFiles,
        totalSizeBytes: totalSize,
      );
    } catch (e) {
      _logger.w('Error checking Firebase Storage (may be empty): $e');
      return StorageStatus(
        totalFiles: 0,
        totalSizeBytes: 0,
        error: e.toString(),
      );
    }
  }

  /// فحص Cloudflare
  Future<CloudflareStatus> _checkCloudflare() async {
    try {
      final isConfigured = await VideoUploadConfig.isCloudflareConfigured();
      if (!isConfigured) {
        return CloudflareStatus(
          isConfigured: false,
          error: 'Cloudflare not configured',
        );
      }

      final service = await CloudflareStreamService.fromConfig();
      if (service == null) {
        return CloudflareStatus(
          isConfigured: false,
          error: 'Failed to initialize Cloudflare service',
        );
      }

      // ملاحظة: Cloudflare API لا يوفر endpoint مباشر لجلب جميع الفيديوهات
      // يجب استخدام Dashboard أو API مع pagination
      // هنا نتحقق فقط من التهيئة

      return CloudflareStatus(
        isConfigured: true,
        note: 'Use Cloudflare Dashboard to check videos count',
      );
    } catch (e) {
      return CloudflareStatus(
        isConfigured: false,
        error: e.toString(),
      );
    }
  }

  /// إصلاح URLs المكسورة باستخدام cloudflareVideoId
  Future<FixUrlsResult> fixBrokenUrls() async {
    try {
      _logger.d('🔧 Fixing broken URLs...');

      final status = await _checkFirestore();
      final subdomain = await VideoUploadConfig.getCloudflareSubdomain();

      if (subdomain == null) {
        return FixUrlsResult(
          success: false,
          error: 'Cloudflare subdomain not configured',
        );
      }

      int fixed = 0;
      int failed = 0;

      for (var entry in status.cloudflareVideoIds.entries) {
        final videoId = entry.key;
        final cloudflareVideoId = entry.value;

        try {
          final newUrl =
              'https://$subdomain.cloudflarestream.com/$cloudflareVideoId/manifest/video.m3u8';

          await _firestore.collection(_collection).doc(videoId).update({
            'url': newUrl,
            'uploadSource': 'cloudflare',
            'fixedAt': FieldValue.serverTimestamp(),
          });

          fixed++;
          _logger.d('✅ Fixed URL for video: $videoId');
        } catch (e) {
          failed++;
          _logger.w('⚠️ Failed to fix video $videoId: $e');
        }
      }

      return FixUrlsResult(
        success: true,
        fixed: fixed,
        failed: failed,
      );
    } catch (e) {
      _logger.e('Error fixing broken URLs: $e');
      return FixUrlsResult(
        success: false,
        error: e.toString(),
      );
    }
  }
}

/// تقرير حالة Firestore
class FirestoreStatus {
  final int total;
  final int firebaseUrls;
  final int cloudflareUrls;
  final int brokenUrls;
  final int hasCloudflareId;
  final List<String> brokenVideoIds;
  final Map<String, String> cloudflareVideoIds; // videoId -> cloudflareVideoId

  FirestoreStatus({
    required this.total,
    required this.firebaseUrls,
    required this.cloudflareUrls,
    required this.brokenUrls,
    required this.hasCloudflareId,
    required this.brokenVideoIds,
    required this.cloudflareVideoIds,
  });
}

/// تقرير حالة Firebase Storage
class StorageStatus {
  final int totalFiles;
  final int totalSizeBytes;
  final String? error;

  StorageStatus({
    required this.totalFiles,
    required this.totalSizeBytes,
    this.error,
  });

  String get totalSizeFormatted {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(2)} KB';
    }
    if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// تقرير حالة Cloudflare
class CloudflareStatus {
  final bool isConfigured;
  final String? error;
  final String? note;

  CloudflareStatus({
    required this.isConfigured,
    this.error,
    this.note,
  });
}

/// تقرير شامل
class VideosStatusReport {
  final FirestoreStatus firestore;
  final StorageStatus firebaseStorage;
  final CloudflareStatus cloudflare;

  VideosStatusReport({
    required this.firestore,
    required this.firebaseStorage,
    required this.cloudflare,
  });
}

/// نتيجة إصلاح URLs
class FixUrlsResult {
  final bool success;
  final int? fixed;
  final int? failed;
  final String? error;

  FixUrlsResult({
    required this.success,
    this.fixed,
    this.failed,
    this.error,
  });
}
