import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/video_model.dart';
import '../models/spotlight_category.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:logger/logger.dart';
import '../../../core/geo/saudi_region_parser.dart';
import '../../../core/time/riyadh_calendar.dart';
import '../../../core/services/media_failure_log_service.dart';
import '../config/video_upload_config.dart';
import 'cloudflare_stream_service.dart';

// إضافة تعريف لجودة الفيديو
enum VideoQuality { auto, low, medium, high }

// إضافة تعريف لحالة الميزات
class FeatureState {
  final String name;
  final bool isEnabled;
  final DateTime enabledAt;

  FeatureState(this.name, this.isEnabled, this.enabledAt);
}

final _logger = Logger();

/// صفحة فيديوهات سبوتلايت مع مؤشر [nextPageStartAfter] لـ Firestore (ترقيم حقيقي).
class SpotlightVideosPage {
  const SpotlightVideosPage({
    required this.videos,
    this.nextPageStartAfter,
    required this.hasMore,
  });

  final List<VideoModel> videos;
  final DocumentSnapshot? nextPageStartAfter;
  final bool hasMore;
}

class VideoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'spotlight_videos';
  
  // متغيرات التحكم في الميزات الجديدة
  bool _enableNewFeatures = false;
  final Map<String, FeatureState> _features = {};
  VideoQuality _currentQuality = VideoQuality.auto;
  double _playbackSpeed = 1.0;

  // إضافة getters للوصول إلى القيم
  bool get enableNewFeatures => _enableNewFeatures;
  VideoQuality get currentQuality => _currentQuality;
  double get playbackSpeed => _playbackSpeed;

  // تحديث تهيئة الفيديو
  Future<Map<String, dynamic>> getVideoSettings(String videoId) async {
    try {
      return {
        'quality': _currentQuality,
        'playbackSpeed': _playbackSpeed,
        'features': _features,
        'enableNewFeatures': _enableNewFeatures
      };
    } catch (e) {
      _logError('Error getting video settings', e);
      return {};
    }
  }

  // تحديث إعدادات الفيديو
  Future<bool> updateVideoSettings(String videoId, {
    VideoQuality? quality,
    double? speed,
    bool? enableFeatures,
  }) async {
    try {
      if (quality != null) _currentQuality = quality;
      if (speed != null) _playbackSpeed = speed;
      if (enableFeatures != null) _enableNewFeatures = enableFeatures;
      return true;
    } catch (e) {
      _logError('Error updating video settings', e);
      return false;
    }
  }

  // دالة لتفعيل الميزات الجديدة
  Future<bool> enableFeature(String featureName) async {
    try {
      _features[featureName] = FeatureState(
        featureName,
        true,
        DateTime.now(),
      );
      return true;
    } catch (e) {
      _logError('Error enabling feature: $featureName', e);
      return false;
    }
  }

  // دالة للتراجع عن الميزات
  Future<void> rollbackFeature(String featureName) async {
    try {
      _features.remove(featureName);
      if (featureName == 'video_quality') {
        _currentQuality = VideoQuality.auto;
      } else if (featureName == 'playback_speed') {
        _playbackSpeed = 1.0;
      }
    } catch (e) {
      _logError('Error rolling back feature: $featureName', e);
    }
  }

  // دالة لاختبار الميزات الجديدة
  Future<bool> testFeature(String featureName) async {
    try {
      switch (featureName) {
        case 'video_quality':
          return await _testVideoQuality();
        case 'playback_speed':
          return await _testPlaybackSpeed();
        default:
          return false;
      }
    } catch (e) {
      _logError('Error testing feature: $featureName', e);
      return false;
    }
  }

  // اختبار جودة الفيديو
  Future<bool> _testVideoQuality() async {
    try {
      // محاكاة اختبار تغيير الجودة
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    }
  }

  // اختبار سرعة التشغيل
  Future<bool> _testPlaybackSpeed() async {
    try {
      // محاكاة اختبار تغيير السرعة
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    }
  }

  // تحديث جودة الفيديو
  Future<bool> setVideoQuality(VideoQuality quality) async {
    try {
      if (!_features.containsKey('video_quality')) {
        return false;
      }
      _currentQuality = quality;
      return true;
    } catch (e) {
      _logError('Error setting video quality', e);
      return false;
    }
  }

  // تحديث سرعة التشغيل
  Future<bool> setPlaybackSpeed(double speed) async {
    try {
      if (!_features.containsKey('playback_speed')) {
        return false;
      }
      _playbackSpeed = speed;
      return true;
    } catch (e) {
      _logError('Error setting playback speed', e);
      return false;
    }
  }

  Future<List<VideoModel>> getVideos({int limit = 20}) async {
    try {
      // إضافة limit لتقليل البيانات المحملة
      final snapshot = await _firestore
          .collection(_collection)
          .limit(limit) // إضافة limit للتحسين
          .get();
      
      // تصفية الفيديوهات التي تحتوي على URLs صحيحة فقط
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            // إضافة id من document id إذا لم يكن موجوداً
            if (!data.containsKey('id') || data['id'] == null || data['id'] == '') {
              data['id'] = doc.id;
            }
            return VideoModel.fromMap(data);
          })
          .where((video) {
            // تصفية الفيديوهات التي تحتوي على URLs من Firebase Storage فقط
            final url = video.url;
            final isValidUrl = url.isNotEmpty && 
                   (url.startsWith('http://') || url.startsWith('https://'));
            if (!isValidUrl) {
              _logger.w('Skipping video ${video.id} with invalid URL: $url');
            }
            return isValidUrl;
          })
          .toList();
    } catch (e) {
      _logger.e('Error fetching videos: $e');
      rethrow;
    }
  }

  /// جلب صفحة فيديوهات بنوع واحد مع ترتيب ثابت في Firestore (لا تكرار عند «تحميل المزيد»).
  ///
  /// يتطلب فهرس مركّب: `type` + `createdAt` — راجع [firestore.indexes.json].
  Future<SpotlightVideosPage> getVideosByType(
    VideoType type, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final typeString = type == VideoType.car ? 'car' : 'realEstate';
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collection)
          .where('type', isEqualTo: typeString)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        return const SpotlightVideosPage(videos: [], hasMore: false);
      }

      final videos = <VideoModel>[];
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        if (!data.containsKey('id') || data['id'] == null || data['id'] == '') {
          data['id'] = doc.id;
        }
        final video = VideoModel.fromMap(data);
        final url = video.url;
        final ok = url.isNotEmpty &&
            (url.startsWith('http://') || url.startsWith('https://'));
        if (!ok) {
          _logger.w('Skipping video ${video.id} with invalid URL: $url');
          continue;
        }
        videos.add(video);
      }

      final hasMore = snapshot.docs.length == limit;
      final cursor = snapshot.docs.last;

      _logger.d(
        'Loaded ${videos.length} videos by type (raw docs: ${snapshot.docs.length}, hasMore: $hasMore)',
      );
      return SpotlightVideosPage(
        videos: videos,
        nextPageStartAfter: cursor,
        hasMore: hasMore,
      );
    } catch (e) {
      _logger.e('Error fetching videos by type: $e');
      // لا نُرجع قائمة فارغة — وإلا تظهر «لا توجد فيديوهات» بدل سبب الحقيقي (صلاحيات، فهرس، شبكة).
      rethrow;
    }
  }

  Future<List<VideoModel>> getVideosByTypeOld(VideoType type) async {
    try {
      if (type == VideoType.car) {
        return [
          VideoModel(
            id: '1',
            url: 'assets/videos/cars/car1_video.mp4',
            thumbnail: 'assets/images/cars/car1_thumb.jpg',
            title: 'مرسيدس S-Class',
            description: 'سيارة فاخرة بمواصفات خاصة',
            type: VideoType.car,
            price: 600000,
            location: const GeoPoint(24.7136, 46.6753),
            address: 'الرياض - حي العليا',
            createdAt: DateTime.now(),
          ),
          VideoModel(
            id: '2',
            url: 'assets/videos/cars/car2_video.mp4',
            thumbnail: 'assets/images/cars/car2_thumb.jpg',
            title: 'BMW الفئة السابعة',
            description: 'سيارة فاخرة مع تقنيات متطورة',
            type: VideoType.car,
            price: 500000,
            location: const GeoPoint(24.7136, 46.6753),
            address: 'الرياض - حي العليا',
            createdAt: DateTime.now(),
          ),
          VideoModel(
            id: '3',
            url: 'assets/videos/cars/car3_video.mp4',
            thumbnail: 'assets/images/cars/car3_thumb.jpg',
            title: 'لكزس LS',
            description: 'سيارة فاخرة مع راحة استثنائية',
            type: VideoType.car,
            price: 450000,
            location: const GeoPoint(24.7136, 46.6753),
            address: 'الرياض - حي العليا',
            createdAt: DateTime.now(),
          ),
        ];
      } else {
        return [
          VideoModel(
            id: '4',
            url: 'assets/videos/real_estate/property1_video.mp4',
            thumbnail: 'assets/images/real_estate/property1_thumb.jpg',
            title: 'فيلا فاخرة',
            description: 'فيلا حديثة مع مسبح خاص',
            type: VideoType.realEstate,
            price: 2500000,
            location: const GeoPoint(24.7136, 46.6753),
            address: 'الرياض - حي الملقا',
            createdAt: DateTime.now(),
          ),
          VideoModel(
            id: '5',
            url: 'assets/videos/real_estate/property2_video.mp4',
            thumbnail: 'assets/images/real_estate/property2_thumb.jpg',
            title: 'شقة مفروشة',
            description: 'شقة فاخرة مع إطلالة رائعة',
            type: VideoType.realEstate,
            price: 1200000,
            location: const GeoPoint(24.7136, 46.6753),
            address: 'الرياض - حي العليا',
            createdAt: DateTime.now(),
          ),
          VideoModel(
            id: '6',
            url: 'assets/videos/real_estate/property3_video.mp4',
            thumbnail: 'assets/images/real_estate/property3_thumb.jpg',
            title: 'فيلا مع حديقة',
            description: 'فيلا واسعة مع حديقة كبيرة',
            type: VideoType.realEstate,
            price: 3000000,
            location: const GeoPoint(24.7136, 46.6753),
            address: 'الرياض - حي النرجس',
            createdAt: DateTime.now(),
          ),
        ];
      }
    } catch (e) {
      _logger.e('Error fetching videos by type: $e');
      rethrow;
    }
  }

  /// صفحة مختلطة (سيارات + عقارات) مع ترتيب [createdAt] في Firestore.
  Future<SpotlightVideosPage> getMixedVideos({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collection)
          .where('type', whereIn: ['car', 'realEstate'])
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        return const SpotlightVideosPage(videos: [], hasMore: false);
      }

      final videos = <VideoModel>[];
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        if (!data.containsKey('id') || data['id'] == null || data['id'] == '') {
          data['id'] = doc.id;
        }
        final video = VideoModel.fromMap(data);
        final url = video.url;
        final ok = url.isNotEmpty &&
            (url.startsWith('http://') || url.startsWith('https://'));
        if (!ok) {
          _logger.w('Skipping video ${video.id} with invalid URL: $url');
          continue;
        }
        videos.add(video);
      }

      final hasMore = snapshot.docs.length == limit;
      final cursor = snapshot.docs.last;

      _logger.d(
        'Loaded ${videos.length} mixed videos (raw docs: ${snapshot.docs.length}, hasMore: $hasMore)',
      );
      return SpotlightVideosPage(
        videos: videos,
        nextPageStartAfter: cursor,
        hasMore: hasMore,
      );
    } catch (e) {
      _logger.e('Error fetching mixed videos: $e');
      rethrow;
    }
  }

  void _logError(String message, dynamic error) {
    if (kDebugMode) {
      print('$message: $error');
    }
  }

  /// توضيح أخطاء الرفع الشائعة (مثلاً حد ~200 ميجابايت للرفع multipart على Stream).
  /// رسائل مراحل النشر (تُعرض في [LoadingOverlay]).
  static const String uploadUiPrepare = 'جاري التجهيز…';
  static const String uploadUiRequestLink = 'جاري طلب رابط الرفع…';
  static const String uploadUiUploadingFile = 'جاري رفع الملف…';
  static const String uploadUiPublishing = 'جاري الحفظ والنشر…';

  static void _safeUploadUi(
    void Function(String phaseMessage, double? fileFraction)? cb,
    String phase,
    double? fraction,
  ) {
    if (cb == null) return;
    try {
      cb(phase, fraction);
    } catch (_) {
      // لا نُسقط الرفع بسبب استدعاء الواجهة بعد إلغاء الشاشة
    }
  }

  /// تقليل تكرار setState أثناء الرفع مع ضمان إرسال 100٪ عند الانتهاء.
  static void Function(double)? _throttledFileProgress(
    void Function(String phaseMessage, double? fileFraction)? ui,
    String phaseMessage, {
    int minIntervalMs = 120,
  }) {
    if (ui == null) return null;
    var lastMs = 0;
    return (double p) {
      final clamped = p.clamp(0.0, 1.0);
      final now = DateTime.now().millisecondsSinceEpoch;
      final isDone = clamped >= 1.0;
      if (!isDone && now - lastMs < minIntervalMs) return;
      lastMs = now;
      try {
        ui(phaseMessage, clamped);
      } catch (_) {}
    };
  }

  String _humanizeCloudflareUploadError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('file size too large') ||
        lower.contains('exceeds the upload maximum')) {
      return 'حجم الفيديو تجاوز حد الرفع المباشر على Cloudflare Stream (حوالي 200 ميجابايت). '
          'جولات العقارات غالباً أطول وأثقل من مقاطع السيارات لذلك تظهر المشكلة هنا غالباً وليس لأن «العقار» مختلف في الخادم. '
          'جرّب تحديث التطبيق (رفع TUS للملفات الكبيرة) أو اختصر الفيديو/قلل الجودة.\n\n'
          '(رسالة الخادم: $raw)';
    }
    return raw;
  }

  /// رفع صورة الغلاف المختارة محلياً ثم تحديث `thumbnail` في Firestore — بعد النشر لتقليل زمن انتظار المستخدم.
  void _enqueueFirebaseThumbnailReplace({
    required String spotlightDocId,
    required String userId,
    required int timestamp,
    required String thumbnailPath,
  }) {
    unawaited(() async {
      try {
        final thumbFileName = '${timestamp}_${userId}_thumb.jpg';
        final thumbRef = _storage.ref().child('thumbnails/$userId/$thumbFileName');
        final thumbMetadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );
        await thumbRef.putFile(File(thumbnailPath), thumbMetadata);
        final url = await thumbRef.getDownloadURL();
        await _firestore.collection(_collection).doc(spotlightDocId).update({'thumbnail': url});
        _logger.d('✅ Background Firebase thumbnail applied: $spotlightDocId');
      } catch (e) {
        _logger.w('⚠️ Background Firebase thumbnail failed (Cloudflare thumbnail remains): $e');
        await MediaFailureLogService.log(
          mediaKind: 'thumbnail',
          context: 'spotlight_thumbnail_storage_bg',
          errorMessage: e.toString(),
          detail: thumbnailPath,
        );
      }
    }());
  }

  Future<VideoModel> uploadVideo({
    required String title,
    required String description,
    required String videoPath,
    required SpotlightCategory category, required GeoPoint location, required String address, String? thumbnailPath,
    double? price,
    void Function(String phaseMessage, double? fileFraction)? onUploadUi,
  }) async {
    try {
      // التحقق من أن المستخدم مسجل دخول
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول أولاً لرفع الفيديو');
      }

      final userId = currentUser.uid;
      String? sellerName;
      String? sellerPhone;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _logger.d('Uploading video: $videoPath for user: $userId');

      VideoService._safeUploadUi(onUploadUi, VideoService.uploadUiPrepare, null);

      // جلب الملف الشخصي + إعدادات Cloudflare بالتوازي لتقليل زمن «النشر» المحسوس.
      late final DocumentSnapshot<Map<String, dynamic>> userDoc;
      late final bool useCloudflare;
      late final bool isConfigured;
      try {
        final parallel = await Future.wait<dynamic>([
          _firestore.collection('users').doc(userId).get(),
          VideoUploadConfig.shouldUseCloudflare(),
          VideoUploadConfig.isCloudflareConfigured(),
        ]);
        userDoc = parallel[0] as DocumentSnapshot<Map<String, dynamic>>;
        useCloudflare = parallel[1] as bool;
        isConfigured = parallel[2] as bool;
      } catch (e) {
        _logger.w('⚠️ Parallel prefetch failed: $e');
        userDoc = await _firestore.collection('users').doc(userId).get();
        useCloudflare = await VideoUploadConfig.shouldUseCloudflare();
        isConfigured = await VideoUploadConfig.isCloudflareConfigured();
      }

      try {
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final profileName = data['name'] as String?;
          final profilePhone = data['phone'] as String?;

          sellerName = (profileName != null && profileName.isNotEmpty)
              ? profileName
              : currentUser.email?.split('@').first;
          sellerPhone = profilePhone;
        } else {
          sellerName = currentUser.email?.split('@').first ?? 'حساب بدون اسم';
        }
      } catch (e) {
        _logger.w('⚠️ Failed to parse seller profile for video upload: $e');
        sellerName = currentUser.email?.split('@').first ?? 'حساب بدون اسم';
      }

      // ✅ التحقق الإلزامي: Cloudflare يجب أن يكون مفعل ومُهيأ
      if (!useCloudflare) {
        throw Exception(
          'Cloudflare Stream غير مفعل. يرجى تفعيل Cloudflare Stream أولاً.\n'
          'لا يمكن رفع الفيديوهات إلى Firebase Storage.',
        );
      }

      if (!isConfigured) {
        throw Exception(
          'Cloudflare Stream غير مُهيأ بشكل كامل.\n'
          'يرجى التحقق من: API Token, Account ID, و Subdomain.\n'
          'لا يمكن رفع الفيديوهات إلى Firebase Storage.',
        );
      }

      final cloudflareService = await CloudflareStreamService.fromConfig();
      if (cloudflareService == null) {
        throw Exception(
          'فشل في تهيئة خدمة Cloudflare Stream.\n'
          'يرجى التحقق من الإعدادات.\n'
          'لا يمكن رفع الفيديوهات إلى Firebase Storage.',
        );
      }

      // ✅ رفع الفيديو إلى Cloudflare Stream فقط (بدون fallback)
      _logger.d('📤 Uploading to Cloudflare Stream (ONLY - no Firebase fallback)...');

      VideoService._safeUploadUi(onUploadUi, VideoService.uploadUiRequestLink, null);

      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        throw Exception('ملف الفيديو غير موجود: $videoPath');
      }

      final result = await cloudflareService.uploadVideo(
        videoFile: videoFile,
        title: title,
        onProgress: VideoService._throttledFileProgress(
          onUploadUi,
          VideoService.uploadUiUploadingFile,
        ),
      );

      // ✅ التحقق من نجاح الرفع - إذا فشل، نرمي خطأ (بدون fallback)
      if (!result.success || result.videoId == null || result.playbackUrl == null) {
        final errorMsg = result.error ?? 'خطأ غير معروف';
        _logger.e('❌ Cloudflare upload failed: $errorMsg');
        final detail = _humanizeCloudflareUploadError(errorMsg);
        throw Exception(
          'فشل في رفع الفيديو إلى Cloudflare Stream:\n$detail\n\n'
          'يرجى التحقق من:\n'
          '1. اتصال الإنترنت\n'
          '2. إعدادات Cloudflare (API Token, Account ID)\n'
          '3. حجم الفيديو أو مدته (جولات العقارات غالباً أكبر من فيديوهات السيارات)',
        );
      }

      _logger.d('✅ Cloudflare upload successful: ${result.videoId}');
      _logger.d('✅ Playback URL: ${result.playbackUrl}');
      
      // ✅ التحقق النهائي: التأكد من أن URL من Cloudflare
      if (!result.playbackUrl!.contains('cloudflarestream.com') && 
          !result.playbackUrl!.contains('.m3u8')) {
        throw Exception(
          'خطأ: URL الفيديو غير صحيح من Cloudflare.\n'
          'URL: ${result.playbackUrl}',
        );
      }

      VideoService._safeUploadUi(onUploadUi, VideoService.uploadUiPublishing, null);

      // صورة الغلاف: تقليل زمن «النشر» — إن وُجدت صورة Cloudflare ننشر فوراً ونؤجل رفع الصورة المخصّصة لتخزين Firebase للخلفية.
      String thumbnailUrl = (result.thumbnailUrl ?? '').trim();
      final hasCfThumb = thumbnailUrl.isNotEmpty;
      final hasLocalThumb = thumbnailPath != null;

      if (hasLocalThumb && !hasCfThumb) {
        try {
          final thumbFileName = '${timestamp}_${userId}_thumb.jpg';
          final thumbRef = _storage.ref().child('thumbnails/$userId/$thumbFileName');

          final thumbMetadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'userId': userId,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          );

          await thumbRef.putFile(File(thumbnailPath!), thumbMetadata);
          thumbnailUrl = await thumbRef.getDownloadURL();
          _logger.d('✅ Thumbnail uploaded to Firebase Storage: $thumbnailUrl');
        } catch (e) {
          _logger.w('⚠️ Failed to upload thumbnail to Firebase: $e');
          await MediaFailureLogService.log(
            mediaKind: 'thumbnail',
            context: 'spotlight_thumbnail_storage',
            errorMessage: e.toString(),
            detail: thumbnailPath,
          );
          thumbnailUrl = '';
        }
      } else if (hasLocalThumb && hasCfThumb) {
        _logger.d(
          '⚡ Fast publish: Cloudflare thumbnail for immediate UI; Firebase custom thumb in background',
        );
        _enqueueFirebaseThumbnailReplace(
          spotlightDocId: result.videoId!,
          userId: userId,
          timestamp: timestamp,
          thumbnailPath: thumbnailPath!,
        );
      } else if (hasCfThumb) {
        _logger.d('✅ Using Cloudflare thumbnail: $thumbnailUrl');
      }

      // إنشاء نموذج الفيديو
      final video = VideoModel(
        id: result.videoId!,
        url: result.playbackUrl!, // HLS URL من Cloudflare
        thumbnail: thumbnailUrl,
        title: title,
        description: description,
        type: category == SpotlightCategory.cars ? VideoType.car : VideoType.realEstate,
        price: price,
        location: location,
        address: address,
        sellerId: userId,
        sellerName: sellerName,
        sellerPhone: sellerPhone,
        createdAt: DateTime.now(),
      );

      // حفظ البيانات في Firestore
      final videoData = video.toMap();
      videoData['userId'] = userId;
      videoData['sellerId'] = userId;
      if (sellerName != null && sellerName.isNotEmpty) {
        videoData['sellerName'] = sellerName;
      }
      if (sellerPhone != null && sellerPhone.isNotEmpty) {
        videoData['sellerPhone'] = sellerPhone;
      }
      videoData['uploadSource'] = 'cloudflare'; // ✅ تأكيد المصدر
      videoData['cloudflareVideoId'] = result.videoId;
      videoData['uploadedAt'] = FieldValue.serverTimestamp();
      SaudiRegionParser.applyToFirestoreMap(
        videoData,
        (videoData['address'] ?? '').toString(),
      );

      await _firestore.collection(_collection).doc(video.id).set(videoData);

      _logger.d('✅ Video uploaded successfully to Cloudflare Stream ONLY: ${video.id}');
      _logger.d('✅ Video URL: ${video.url}');
      _logger.d('✅ Stored in Firestore with uploadSource: cloudflare');
      
      // ✅ إرجاع الفيديو - الكود ينتهي هنا
      // ❌ لا يوجد أي كود لرفع الفيديو إلى Firebase Storage بعد هذا السطر
      return video;
    } catch (e) {
      _logger.e('Error uploading video: $e');
      await MediaFailureLogService.log(
        mediaKind: 'video',
        context: 'spotlight_cloudflare',
        errorMessage: e.toString(),
        detail: videoPath,
      );
      rethrow;
    }
  }

  Future<VideoModel?> getVideo(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return VideoModel.fromMap(doc.data()!);
    } catch (e) {
      _logger.e('Error fetching video: $e');
      rethrow;
    }
  }

  Future<List<VideoModel>> getVideosByCategory(SpotlightCategory category, {int limit = 20}) async {
    try {
      // إضافة limit لتقليل البيانات المحملة
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: _getCategoryString(category))
          .limit(limit) // إضافة limit للتحسين
          .get();

      // تصفية الفيديوهات التي تحتوي على URLs صحيحة فقط
      final videos = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // إضافة id من document id إذا لم يكن موجوداً
            if (!data.containsKey('id') || data['id'] == null || data['id'] == '') {
              data['id'] = doc.id;
            }
            return VideoModel.fromMap(data);
          })
          .where((video) {
            // تصفية الفيديوهات التي تحتوي على URLs من Firebase Storage فقط
            final url = video.url;
            final isValidUrl = url.isNotEmpty && 
                   (url.startsWith('http://') || url.startsWith('https://'));
            if (!isValidUrl) {
              _logger.w('Skipping video ${video.id} with invalid URL: $url');
            }
            return isValidUrl;
          })
          .toList();
      
      // ترتيب الفيديوهات حسب التاريخ محلياً
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return videos;
    } catch (e) {
      _logger.e('Error fetching videos: $e');
      return [];
    }
  }

  String _getCategoryString(SpotlightCategory category) {
    switch (category) {
      case SpotlightCategory.cars:
        return 'car';
      case SpotlightCategory.realEstate:
        return 'realEstate';
      case SpotlightCategory.mixed:
        return 'mixed';
      case SpotlightCategory.featured:
        return 'featured';
    }
  }

  /// جلب عدد الفيديوهات لكل فئة (للعرض فقط - بدون تحميل الفيديوهات)
  Future<int> getVideoCountByCategory(SpotlightCategory category) async {
    try {
      if (category == SpotlightCategory.mixed) {
        // للكل: جلب جميع الفيديوهات
        final snapshot = await _firestore
            .collection(_collection)
            .where('type', whereIn: ['car', 'realEstate'])
            .get();
        
        // تصفية الفيديوهات التي تحتوي على URLs صحيحة فقط
        final validCount = snapshot.docs.where((doc) {
          final data = doc.data();
          final url = data['url'] as String? ?? '';
          return url.isNotEmpty && 
                 (url.startsWith('http://') || url.startsWith('https://'));
        }).length;
        
        return validCount;
      } else {
        // للسيارات أو العقارات: جلب حسب النوع
        final typeString = category == SpotlightCategory.cars ? 'car' : 'realEstate';
        final snapshot = await _firestore
            .collection(_collection)
            .where('type', isEqualTo: typeString)
            .get();
        
        // تصفية الفيديوهات التي تحتوي على URLs صحيحة فقط
        final validCount = snapshot.docs.where((doc) {
          final data = doc.data();
          final url = data['url'] as String? ?? '';
          return url.isNotEmpty && 
                 (url.startsWith('http://') || url.startsWith('https://'));
        }).length;
        
        return validCount;
      }
    } catch (e) {
      _logger.e('Error getting video count: $e');
      return 0;
    }
  }

  /// حذف فيديو
  Future<bool> deleteVideo(String videoId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      // جلب بيانات الفيديو للتحقق من الملكية
      final videoDoc = await _firestore.collection(_collection).doc(videoId).get();
      if (!videoDoc.exists) {
        throw Exception('الفيديو غير موجود');
      }

      final videoData = videoDoc.data()!;
      final videoUserId = videoData['userId'] as String?;

      // التحقق من أن المستخدم هو صاحب الفيديو
      if (videoUserId != currentUser.uid) {
        throw Exception('ليس لديك صلاحية لحذف هذا الفيديو');
      }

      // التحقق من مصدر الرفع (Cloudflare أو Firebase)
      final uploadSource = videoData['uploadSource'] as String?;
      final cloudflareVideoId = videoData['cloudflareVideoId'] as String?;

      // حذف من Cloudflare إذا كان من Cloudflare
      if (uploadSource == 'cloudflare' && cloudflareVideoId != null) {
        try {
          final cloudflareService = await CloudflareStreamService.fromConfig();
          if (cloudflareService != null) {
            await cloudflareService.deleteSpotlightVideo(spotlightDocId: videoId);
            _logger.d('Video deleted from Cloudflare: $cloudflareVideoId');
          }
        } catch (e) {
          _logger.w('Failed to delete from Cloudflare (continuing with Firestore): $e');
          // نكمل حذف Firestore حتى لو فشل Cloudflare
        }
      }

      // حذف من Firebase Storage إذا كان من Firebase
      if (uploadSource != 'cloudflare') {
        try {
          final videoUrl = videoData['url'] as String?;
          if (videoUrl != null && videoUrl.contains('firebasestorage.googleapis.com')) {
            // استخراج مسار الملف من URL
            final uri = Uri.parse(videoUrl);
            final pathSegments = uri.pathSegments;
            if (pathSegments.isNotEmpty) {
              // مسار Firebase Storage عادة يكون: /v0/b/{bucket}/o/{path}
              final pathIndex = pathSegments.indexOf('o');
              if (pathIndex != -1 && pathIndex < pathSegments.length - 1) {
                final filePath = pathSegments.sublist(pathIndex + 1).join('/');
                final decodedPath = Uri.decodeComponent(filePath);
                final videoRef = _storage.ref(decodedPath);
                await videoRef.delete();
                _logger.d('Video deleted from Firebase Storage: $decodedPath');
              }
            }
          }
        } catch (e) {
          _logger.w('Failed to delete from Firebase Storage (continuing with Firestore): $e');
          // نكمل حذف Firestore حتى لو فشل Storage
        }

        // حذف thumbnail من Firebase Storage
        try {
          final thumbnailUrl = videoData['thumbnail'] as String?;
          if (thumbnailUrl != null && thumbnailUrl.contains('firebasestorage.googleapis.com')) {
            final uri = Uri.parse(thumbnailUrl);
            final pathSegments = uri.pathSegments;
            if (pathSegments.isNotEmpty) {
              final pathIndex = pathSegments.indexOf('o');
              if (pathIndex != -1 && pathIndex < pathSegments.length - 1) {
                final filePath = pathSegments.sublist(pathIndex + 1).join('/');
                final decodedPath = Uri.decodeComponent(filePath);
                final thumbRef = _storage.ref(decodedPath);
                await thumbRef.delete();
                _logger.d('Thumbnail deleted from Firebase Storage: $decodedPath');
              }
            }
          }
        } catch (e) {
          _logger.w('Failed to delete thumbnail (continuing): $e');
        }
      }

      // حذف من Firestore
      await _firestore.collection(_collection).doc(videoId).delete();
      _logger.d('Video deleted successfully: $videoId');
      return true;
    } catch (e) {
      _logger.e('Error deleting video: $e');
      rethrow;
    }
  }

  /// تحديث فيديو
  Future<VideoModel> updateVideo({
    required String videoId,
    String? title,
    String? description,
    double? price,
    GeoPoint? location,
    String? address,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      // جلب بيانات الفيديو للتحقق من الملكية
      final videoDoc = await _firestore.collection(_collection).doc(videoId).get();
      if (!videoDoc.exists) {
        throw Exception('الفيديو غير موجود');
      }

      final videoData = videoDoc.data()!;
      final videoUserId = videoData['userId'] as String?;

      // التحقق من أن المستخدم هو صاحب الفيديو
      if (videoUserId != currentUser.uid) {
        throw Exception('ليس لديك صلاحية لتعديل هذا الفيديو');
      }

      // إنشاء خريطة التحديثات
      final Map<String, dynamic> updates = {};

      if (title != null && title.isNotEmpty) {
        updates['title'] = title;
      }
      if (description != null && description.isNotEmpty) {
        updates['description'] = description;
      }
      if (price != null) {
        updates['price'] = price;
      }
      if (location != null) {
        updates['location'] = location;
      }
      if (address != null && address.isNotEmpty) {
        updates['address'] = address;
      }

      if (updates.isEmpty) {
        throw Exception('لا توجد تحديثات لتطبيقها');
      }

      final addrForGeo = (updates['address'] ?? videoData['address'] ?? '').toString();
      final merged = Map<String, dynamic>.from(videoData)..addAll(updates);
      SaudiRegionParser.applyToFirestoreMap(merged, addrForGeo);
      updates['city'] = merged['city'];
      updates['district'] = merged['district'];

      // إضافة timestamp للتحديث
      updates['updatedAt'] = FieldValue.serverTimestamp();

      // تحديث في Firestore
      await _firestore.collection(_collection).doc(videoId).update(updates);

      // جلب الفيديو المحدث
      final updatedDoc = await _firestore.collection(_collection).doc(videoId).get();
      final updatedData = updatedDoc.data()!;
      if (!updatedData.containsKey('id') || updatedData['id'] == null) {
        updatedData['id'] = videoId;
      }

      _logger.d('Video updated successfully: $videoId');
      return VideoModel.fromMap(updatedData);
    } catch (e) {
      _logger.e('Error updating video: $e');
      rethrow;
    }
  }

  static const String _dailyViewsCollection = 'spotlight_daily_views';

  /// زيادة عدد المشاهدات على الفيديو + تجميع يومي (توقيت السعودية) للوحة الإدارة.
  Future<void> incrementViewsCount(String videoId) async {
    final dayKey = RiyadhCalendar.todayDateKey();
    final videoRef = _firestore.collection(_collection).doc(videoId);
    final dailyRef = _firestore.collection(_dailyViewsCollection).doc(dayKey);
    try {
      final batch = _firestore.batch();
      batch.update(videoRef, {'viewsCount': FieldValue.increment(1)});
      batch.set(
        dailyRef,
        {
          'totalViews': FieldValue.increment(1),
          'dateKey': dayKey,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      _logger.d('Views count + daily rollup for $videoId ($dayKey)');
    } catch (e) {
      _logger.e('Batch views increment failed, video-only fallback: $e');
      try {
        await videoRef.update({'viewsCount': FieldValue.increment(1)});
      } catch (e2) {
        _logger.e('Error incrementing views count: $e2');
      }
    }
  }

  static bool _snapshotDocHasPlayableUrl(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw is! Map<String, dynamic>) return false;
    final url = raw['url'] as String? ?? '';
    return url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));
  }

  VideoModel _videoModelFromSnapshot(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data()! as Map<String, dynamic>);
    if (!data.containsKey('id') ||
        data['id'] == null ||
        data['id'].toString().trim().isEmpty) {
      data['id'] = doc.id;
    }
    return VideoModel.fromMap(data);
  }

  /// جلب فيديوهات المستخدم
  Future<List<VideoModel>> getVideosByUserId(String userId, {int limit = 50}) async {
    try {
      final uid = userId.trim();
      if (uid.isEmpty) return [];

      // بدون orderBy لتفادي الحاجة لفهرس مركّب؛ الترتيب محلياً حسب createdAt
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: uid)
          .limit(limit)
          .get();

      final videos = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            if (!data.containsKey('id') ||
                data['id'] == null ||
                data['id'].toString().trim().isEmpty) {
              data['id'] = doc.id;
            }
            return VideoModel.fromMap(data);
          })
          .toList();
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return videos;
    } catch (e) {
      _logger.e('Error fetching user videos: $e');
      return [];
    }
  }

  /// جلب فيديوهات حسب sellerId (البائع)
  ///
  /// يدمج `sellerId` و`userId` (مقاطع قديمة)، بدون orderBy على السيرفر
  /// لتفادي فشل الاستعلام عند غياب الفهرس المركّب؛ الترتيب محلياً.
  Future<List<VideoModel>> getVideosBySellerId(String sellerId, {int limit = 20}) async {
    final sid = sellerId.trim();
    if (sid.isEmpty) return [];

    try {
      _logger.d('🔍 Fetching videos for seller: $sid');

      final byId = <String, VideoModel>{};

      Future<void> mergeWhere(String field) async {
        final snap = await _firestore
            .collection(_collection)
            .where(field, isEqualTo: sid)
            .limit(150)
            .get();
        for (final doc in snap.docs) {
          if (!_snapshotDocHasPlayableUrl(doc)) {
            _logger.w('Skipping video ${doc.id} (no playable URL)');
            continue;
          }
          byId[doc.id] = _videoModelFromSnapshot(doc);
        }
      }

      await mergeWhere('sellerId');
      await mergeWhere('userId');

      final videos = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _logger.d('✅ Found ${videos.length} videos for seller: $sid');
      if (videos.length > limit) {
        return videos.sublist(0, limit);
      }
      return videos;
    } catch (e, st) {
      _logger.e('❌ Error fetching videos by seller: $e\n$st');
      return [];
    }
  }

  /// جلب عدد فيديوهات البائع (مطابق لمنطق القائمة)
  Future<int> getVideoCountBySellerId(String sellerId) async {
    final sid = sellerId.trim();
    if (sid.isEmpty) return 0;

    try {
      final ids = <String>{};

      Future<void> collectIds(String field) async {
        final snap = await _firestore
            .collection(_collection)
            .where(field, isEqualTo: sid)
            .get();
        for (final doc in snap.docs) {
          if (_snapshotDocHasPlayableUrl(doc)) {
            ids.add(doc.id);
          }
        }
      }

      await collectIds('sellerId');
      await collectIds('userId');

      return ids.length;
    } catch (e) {
      _logger.e('Error getting video count by seller: $e');
      return 0;
    }
  }
} 