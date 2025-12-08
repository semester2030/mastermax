import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_model.dart';
import '../models/spotlight_category.dart';
import '../services/video_service.dart';

class VideoProvider with ChangeNotifier {
  final VideoService _videoService;
  
  VideoProvider(this._videoService);
  
  List<VideoModel> _videos = [];
  final Set<String> _likedVideos = {};
  bool _isLoading = false;
  String? _error;
  VideoQuality _currentQuality = VideoQuality.auto;
  double _playbackSpeed = 1.0;
  Map<String, dynamic> _videoSettings = {};

  List<VideoModel> get videos => _videos;
  Set<String> get likedVideos => _likedVideos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  VideoQuality get currentQuality => _currentQuality;
  double get playbackSpeed => _playbackSpeed;
  Map<String, dynamic> get videoSettings => _videoSettings;

  Future<void> uploadVideo({
    required String title,
    required String description,
    required String videoPath,
    required SpotlightCategory category, required GeoPoint location, required String address, String? thumbnailPath,
    double? price,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // استخدام VideoService لرفع الفيديو
      final video = await _videoService.uploadVideo(
        title: title,
        description: description,
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
        category: category,
        location: location,
        address: address,
        price: price,
      );

      // إضافة الفيديو إلى القائمة المحلية
      _videos.insert(0, video);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCarVideos() async {
    await _loadVideos(VideoType.car);
  }

  Future<void> loadRealEstateVideos() async {
    await _loadVideos(VideoType.realEstate);
  }

  Future<void> loadMixedVideos() async {
    try {
      _isLoading = true;
      notifyListeners();

      _videos = await _videoService.getMixedVideos();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadVideos(VideoType type) async {
    try {
      _isLoading = true;
      notifyListeners();

      _videos = await _videoService.getVideosByType(type);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleLike(String videoId) {
    if (_likedVideos.contains(videoId)) {
      _likedVideos.remove(videoId);
    } else {
      _likedVideos.add(videoId);
    }
    notifyListeners();
  }

  Future<void> setVideoQuality(VideoQuality quality) async {
    try {
      final success = await _videoService.setVideoQuality(quality);
      if (success) {
        _currentQuality = quality;
        notifyListeners();
      }
    } catch (e) {
      _error = 'فشل في تحديث جودة الفيديو';
      notifyListeners();
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      final success = await _videoService.setPlaybackSpeed(speed);
      if (success) {
        _playbackSpeed = speed;
        notifyListeners();
      }
    } catch (e) {
      _error = 'فشل في تحديث سرعة التشغيل';
      notifyListeners();
    }
  }

  Future<bool> enableFeature(String featureName) async {
    try {
      final success = await _videoService.enableFeature(featureName);
      if (success) {
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'فشل في تفعيل الميزة';
      notifyListeners();
      return false;
    }
  }

  Future<void> rollbackFeature(String featureName) async {
    try {
      await _videoService.rollbackFeature(featureName);
      if (featureName == 'video_quality') {
        _currentQuality = VideoQuality.auto;
      } else if (featureName == 'playback_speed') {
        _playbackSpeed = 1.0;
      }
      notifyListeners();
    } catch (e) {
      _error = 'فشل في التراجع عن الميزة';
      notifyListeners();
    }
  }

  Future<void> loadVideoSettings(String videoId) async {
    try {
      _videoSettings = await _videoService.getVideoSettings(videoId);
      _currentQuality = _videoSettings['quality'] as VideoQuality;
      _playbackSpeed = _videoSettings['playbackSpeed'] as double;
      notifyListeners();
    } catch (e) {
      _error = 'فشل في تحميل إعدادات الفيديو';
      notifyListeners();
    }
  }

  Future<void> updateVideoSettings(String videoId, {
    VideoQuality? quality,
    double? speed,
    bool? enableFeatures,
  }) async {
    try {
      final success = await _videoService.updateVideoSettings(
        videoId,
        quality: quality,
        speed: speed,
        enableFeatures: enableFeatures,
      );
      
      if (success) {
        await loadVideoSettings(videoId);
      }
    } catch (e) {
      _error = 'فشل في تحديث إعدادات الفيديو';
      notifyListeners();
    }
  }
} 