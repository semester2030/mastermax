import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_model.dart';
import '../services/video_service.dart';
import '../models/spotlight_category.dart';
import '../../favorites/providers/favorites_provider.dart';

class VideoProvider with ChangeNotifier {
  final VideoService _videoService;
  FavoritesProvider? _favoritesProvider;
  String? _currentUserId;
  
  VideoProvider(this._videoService);
  
  void setFavoritesProvider(FavoritesProvider provider, String userId) {
    _favoritesProvider = provider;
    _currentUserId = userId;
  }
  
  List<VideoModel> _videos = [];
  final Set<String> _likedVideos = {};
  bool _isLoading = false;
  bool _isPaging = false;
  bool _hasMore = true; // للتحقق من وجود المزيد
  DocumentSnapshot? _carCursor;
  DocumentSnapshot? _realEstateCursor;
  DocumentSnapshot? _mixedCursor;
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
    void Function(String phaseMessage, double? fileFraction)? onUploadUi,
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
        onUploadUi: onUploadUi,
      );

      // إضافة الفيديو إلى القائمة المحلية
      _videos.insert(0, video);
      _error = null;
      notifyListeners();
      
      // ✅ إشعار لتحديث عدد المقاطع في الشاشات الأخرى
      debugPrint('✅ Video uploaded - counts should be refreshed');
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
    await _loadVideos(VideoType.car, reset: true);
  }

  Future<void> loadRealEstateVideos() async {
    await _loadVideos(VideoType.realEstate, reset: true);
  }

  Future<void> loadMixedVideos() async {
    try {
      _isLoading = true;
      _hasMore = true;
      _mixedCursor = null;
      notifyListeners();

      final page = await _videoService.getMixedVideos(limit: 20, startAfter: null);
      _videos = page.videos;
      _mixedCursor = page.nextPageStartAfter;
      _hasMore = page.hasMore;
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

  Future<void> _loadVideos(VideoType type, {bool reset = false}) async {
    try {
      if (reset) {
        _isLoading = true;
        _hasMore = true;
        if (type == VideoType.car) {
          _carCursor = null;
        } else {
          _realEstateCursor = null;
        }
        notifyListeners();
      }

      final DocumentSnapshot? startAfter = reset
          ? null
          : (type == VideoType.car ? _carCursor : _realEstateCursor);

      final SpotlightVideosPage page = await _videoService.getVideosByType(
        type,
        limit: 20,
        startAfter: startAfter,
      );

      if (reset) {
        _videos = page.videos;
      } else {
        for (final v in page.videos) {
          if (!_videos.any((e) => e.id == v.id)) {
            _videos.add(v);
          }
        }
      }

      if (type == VideoType.car) {
        _carCursor = page.nextPageStartAfter;
      } else {
        _realEstateCursor = page.nextPageStartAfter;
      }
      _hasMore = page.hasMore;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      if (reset) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  // دوال تحميل المزيد
  Future<void> loadMoreCarVideos() async {
    if (!_hasMore || _isLoading || _isPaging) return;
    _isPaging = true;
    try {
      await _loadVideos(VideoType.car, reset: false);
    } finally {
      _isPaging = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreRealEstateVideos() async {
    if (!_hasMore || _isLoading || _isPaging) return;
    _isPaging = true;
    try {
      await _loadVideos(VideoType.realEstate, reset: false);
    } finally {
      _isPaging = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreMixedVideos() async {
    if (!_hasMore || _isLoading || _isPaging) return;
    _isPaging = true;
    try {
      final page = await _videoService.getMixedVideos(
        limit: 20,
        startAfter: _mixedCursor,
      );
      for (final v in page.videos) {
        if (!_videos.any((e) => e.id == v.id)) {
          _videos.add(v);
        }
      }
      _mixedCursor = page.nextPageStartAfter;
      _hasMore = page.hasMore;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isPaging = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String videoId) async {
    try {
      // البحث عن الفيديو - مع معالجة الخطأ
      final video = _videos.firstWhere(
        (v) => v.id == videoId,
        orElse: () => throw Exception('الفيديو غير موجود'),
      );
      
      if (_likedVideos.contains(videoId)) {
        _likedVideos.remove(videoId);
        // إزالة من المفضلة
        if (_favoritesProvider != null && _currentUserId != null) {
          try {
            await _favoritesProvider!.removeFromFavorites(videoId, _currentUserId!);
          } catch (e) {
            debugPrint('[VideoProvider] خطأ في إزالة من المفضلة: $e');
            // نعيد اللايك في حالة فشل الحذف
            _likedVideos.add(videoId);
          }
        }
      } else {
        _likedVideos.add(videoId);
        // إضافة للمفضلة
        if (_favoritesProvider != null && _currentUserId != null) {
          try {
            await _favoritesProvider!.addToFavorites(video, _currentUserId!);
          } catch (e) {
            debugPrint('[VideoProvider] خطأ في إضافة للمفضلة: $e');
            // نزيل اللايك في حالة فشل الإضافة
            _likedVideos.remove(videoId);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[VideoProvider] خطأ في toggleLike: $e');
      _error = 'حدث خطأ أثناء تحديث الإعجاب';
      notifyListeners();
    }
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

  /// حذف فيديو
  Future<bool> deleteVideo(String videoId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final success = await _videoService.deleteVideo(videoId);

      if (success) {
        // إزالة الفيديو من القائمة المحلية
        _videos.removeWhere((v) => v.id == videoId);
        _likedVideos.remove(videoId);
        _error = null;
        notifyListeners();
        
        // ✅ إشعار لتحديث عدد المقاطع في الشاشات الأخرى
        debugPrint('✅ Video deleted - counts should be refreshed');
      }

      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تحديث فيديو
  Future<VideoModel?> updateVideo({
    required String videoId,
    String? title,
    String? description,
    double? price,
    GeoPoint? location,
    String? address,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updatedVideo = await _videoService.updateVideo(
        videoId: videoId,
        title: title,
        description: description,
        price: price,
        location: location,
        address: address,
      );

      // تحديث الفيديو في القائمة المحلية
      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        _videos[index] = updatedVideo;
      }

      _error = null;
      notifyListeners();
      return updatedVideo;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// زيادة عدد المشاهدات
  Future<void> incrementViewsCount(String videoId) async {
    try {
      await _videoService.incrementViewsCount(videoId);

      // تحديث القيمة المحلية
      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        final video = _videos[index];
        _videos[index] = video.copyWith(
          viewsCount: video.viewsCount + 1,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error incrementing views count: $e');
      // لا نعرض خطأ للمستخدم - هذا ليس حرجاً
    }
  }

  /// جلب فيديوهات المستخدم
  Future<List<VideoModel>> getUserVideos(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final videos = await _videoService.getVideosByUserId(userId);
      _videos = List<VideoModel>.from(videos);
      _hasMore = false;
      _error = null;
      notifyListeners();
      return videos;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// جلب عدد الفيديوهات لكل فئة
  Future<int> getVideoCountByCategory(SpotlightCategory category) async {
    try {
      final videos = await _videoService.getVideosByCategory(category, limit: 10000);
      return videos.length;
    } catch (e) {
      debugPrint('Error getting video count: $e');
      return 0;
    }
  }

  /// جلب عدد الفيديوهات لجميع الفئات
  Future<Map<SpotlightCategory, int>> getAllVideoCounts() async {
    try {
      final carsCount = await getVideoCountByCategory(SpotlightCategory.cars);
      final realEstateCount = await getVideoCountByCategory(SpotlightCategory.realEstate);
      final mixedCount = await getVideoCountByCategory(SpotlightCategory.mixed);
      
      return {
        SpotlightCategory.cars: carsCount,
        SpotlightCategory.realEstate: realEstateCount,
        SpotlightCategory.mixed: mixedCount,
      };
    } catch (e) {
      debugPrint('Error getting all video counts: $e');
      return {
        SpotlightCategory.cars: 0,
        SpotlightCategory.realEstate: 0,
        SpotlightCategory.mixed: 0,
      };
    }
  }

  /// جلب فيديوهات البائع (seller)
  Future<void> loadSellerVideos(String sellerId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final videos = await _videoService.getVideosBySellerId(sellerId);
      _videos = videos;
      _hasMore = videos.length >= 20;
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading seller videos: $e');
    }
  }

  /// جلب عدد فيديوهات البائع
  Future<int> getSellerVideoCount(String sellerId) async {
    try {
      return await _videoService.getVideoCountBySellerId(sellerId);
    } catch (e) {
      debugPrint('Error getting seller video count: $e');
      return 0;
    }
  }

  /// جلب فيديو حسب المعرف
  Future<VideoModel?> getVideoById(String videoId) async {
    try {
      return await _videoService.getVideo(videoId);
    } catch (e) {
      debugPrint('Error getting video by id: $e');
      return null;
    }
  }
} 