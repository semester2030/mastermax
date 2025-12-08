import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/video_model.dart';
import '../models/spotlight_category.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:logger/logger.dart';

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

  Future<List<VideoModel>> getVideos() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => VideoModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      _logger.e('Error fetching videos: $e');
      rethrow;
    }
  }

  Future<List<VideoModel>> getVideosByType(VideoType type) async {
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

  Future<List<VideoModel>> getMixedVideos() async {
    try {
      // جلب الفيديوهات من Firestore مع التصفية حسب النوع
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('type', whereIn: ['car', 'realEstate'])  // فقط السيارات والعقارات
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => VideoModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
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

  Future<VideoModel> uploadVideo({
    required String title,
    required String description,
    required String videoPath,
    required SpotlightCategory category, required GeoPoint location, required String address, String? thumbnailPath,
    double? price,
  }) async {
    try {
      _logger.d('Uploading video: $videoPath');
      // 1. رفع الفيديو
      final videoRef = _storage.ref().child('videos/${DateTime.now().millisecondsSinceEpoch}.mp4');
      await videoRef.putFile(File(videoPath));
      final videoUrl = await videoRef.getDownloadURL();

      // 2. رفع الصورة المصغرة
      String thumbnailUrl = '';
      if (thumbnailPath != null) {
        final thumbRef = _storage.ref().child('thumbnails/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await thumbRef.putFile(File(thumbnailPath));
        thumbnailUrl = await thumbRef.getDownloadURL();
      }

      // 3. إنشاء نموذج الفيديو
      final video = VideoModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: videoUrl,
        thumbnail: thumbnailUrl,
        title: title,
        description: description,
        type: category == SpotlightCategory.cars ? VideoType.car : VideoType.realEstate,
        price: price,
        location: location,
        address: address,
        createdAt: DateTime.now(),
      );

      // 4. حفظ البيانات في Firestore
      await _firestore.collection(_collection).doc(video.id).set(video.toMap());

      return video;
    } catch (e) {
      _logger.e('Error uploading video: $e');
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

  Future<List<VideoModel>> getVideosByCategory(SpotlightCategory category) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('videos')
          .where('type', isEqualTo: _getCategoryString(category))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => VideoModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
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
} 