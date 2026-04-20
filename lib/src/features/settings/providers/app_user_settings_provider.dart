import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../spotlight/services/video_service.dart';

/// إعدادات تطبيق «دار كار» المحفوظة محلياً (عرض، محتوى، إشعارات).
class AppUserSettingsProvider extends ChangeNotifier {
  AppUserSettingsProvider() {
    _loadFuture = _load();
  }

  late final Future<void> _loadFuture;

  static const String _kAutoPlay = 'dk_auto_play_videos';
  static const String _kShowViews = 'dk_show_views_count';
  static const String _kVideoQuality = 'dk_video_quality';
  static const String _kWatermark = 'dk_watermark_videos';
  static const String _kLocationContent = 'dk_location_based_content';
  static const String _kAutoSave = 'dk_auto_save_drafts';
  static const String _kDefaultPrivacy = 'dk_default_video_privacy';
  static const String _kNotifyViews = 'dk_notify_views';
  static const String _kNotifyComments = 'dk_notify_comments';
  static const String _kNotifyLikes = 'dk_notify_likes';
  static const String _kViewsThreshold = 'dk_views_notification_threshold';

  bool _ready = false;
  bool _autoPlayVideos = true;
  bool _showViewsCount = true;
  VideoQuality _videoQuality = VideoQuality.high;
  bool _enableWatermarkVideos = true;
  bool _locationBasedContent = true;
  bool _autoSaveDrafts = true;
  String _defaultPrivacy = 'public';
  bool _notifyNewViews = true;
  bool _notifyComments = true;
  bool _notifyLikes = true;
  int _viewsNotificationThreshold = 1000;

  bool get isReady => _ready;
  bool get autoPlayVideos => _autoPlayVideos;
  bool get showViewsCount => _showViewsCount;
  VideoQuality get videoQuality => _videoQuality;
  bool get enableWatermarkVideos => _enableWatermarkVideos;
  bool get locationBasedContent => _locationBasedContent;
  bool get autoSaveDrafts => _autoSaveDrafts;
  String get defaultPrivacy => _defaultPrivacy;
  bool get notifyNewViews => _notifyNewViews;
  bool get notifyComments => _notifyComments;
  bool get notifyLikes => _notifyLikes;
  int get viewsNotificationThreshold => _viewsNotificationThreshold;

  Future<void> ensureLoaded() => _loadFuture;

  static String videoQualityLabelAr(VideoQuality q) {
    switch (q) {
      case VideoQuality.high:
        return 'عالية';
      case VideoQuality.medium:
        return 'متوسطة';
      case VideoQuality.low:
        return 'منخفضة';
      case VideoQuality.auto:
        return 'تلقائي';
    }
  }

  static VideoQuality videoQualityFromLabelAr(String label) {
    switch (label.trim()) {
      case 'عالية':
        return VideoQuality.high;
      case 'متوسطة':
        return VideoQuality.medium;
      case 'منخفضة':
        return VideoQuality.low;
      case 'تلقائي':
        return VideoQuality.auto;
      default:
        return VideoQuality.high;
    }
  }

  static String privacyLabelAr(String code) {
    switch (code) {
      case 'private':
        return 'خاص';
      case 'custom':
        return 'مخصص';
      case 'public':
      default:
        return 'عام';
    }
  }

  static String privacyCodeFromLabelAr(String label) {
    switch (label.trim()) {
      case 'خاص':
        return 'private';
      case 'مخصص':
        return 'custom';
      case 'عام':
      default:
        return 'public';
    }
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _autoPlayVideos = p.getBool(_kAutoPlay) ?? true;
      _showViewsCount = p.getBool(_kShowViews) ?? true;
      final qName = p.getString(_kVideoQuality);
      _videoQuality = qName != null ? _decodeQuality(qName) : VideoQuality.high;
      _enableWatermarkVideos = p.getBool(_kWatermark) ?? true;
      _locationBasedContent = p.getBool(_kLocationContent) ?? true;
      _autoSaveDrafts = p.getBool(_kAutoSave) ?? true;
      _defaultPrivacy = p.getString(_kDefaultPrivacy) ?? 'public';
      _notifyNewViews = p.getBool(_kNotifyViews) ?? true;
      _notifyComments = p.getBool(_kNotifyComments) ?? true;
      _notifyLikes = p.getBool(_kNotifyLikes) ?? true;
      _viewsNotificationThreshold = p.getInt(_kViewsThreshold) ?? 1000;
    } catch (e, st) {
      debugPrint('AppUserSettingsProvider._load: $e\n$st');
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  static String _encodeQuality(VideoQuality q) {
    switch (q) {
      case VideoQuality.high:
        return 'high';
      case VideoQuality.medium:
        return 'medium';
      case VideoQuality.low:
        return 'low';
      case VideoQuality.auto:
        return 'auto';
    }
  }

  static VideoQuality _decodeQuality(String name) {
    switch (name) {
      case 'medium':
        return VideoQuality.medium;
      case 'low':
        return VideoQuality.low;
      case 'auto':
        return VideoQuality.auto;
      case 'high':
      default:
        return VideoQuality.high;
    }
  }

  Future<void> setAutoPlayVideos(bool v) async {
    _autoPlayVideos = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kAutoPlay, v);
    } catch (e, st) {
      debugPrint('setAutoPlayVideos: $e\n$st');
    }
  }

  Future<void> setShowViewsCount(bool v) async {
    _showViewsCount = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kShowViews, v);
    } catch (e, st) {
      debugPrint('setShowViewsCount: $e\n$st');
    }
  }

  Future<void> setVideoQuality(VideoQuality q) async {
    _videoQuality = q;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kVideoQuality, _encodeQuality(q));
    } catch (e, st) {
      debugPrint('setVideoQuality: $e\n$st');
    }
  }

  Future<void> setEnableWatermarkVideos(bool v) async {
    _enableWatermarkVideos = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kWatermark, v);
    } catch (e, st) {
      debugPrint('setEnableWatermarkVideos: $e\n$st');
    }
  }

  Future<void> setLocationBasedContent(bool v) async {
    _locationBasedContent = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kLocationContent, v);
    } catch (e, st) {
      debugPrint('setLocationBasedContent: $e\n$st');
    }
  }

  Future<void> setAutoSaveDrafts(bool v) async {
    _autoSaveDrafts = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kAutoSave, v);
    } catch (e, st) {
      debugPrint('setAutoSaveDrafts: $e\n$st');
    }
  }

  Future<void> setDefaultPrivacyCode(String code) async {
    _defaultPrivacy = code;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kDefaultPrivacy, code);
    } catch (e, st) {
      debugPrint('setDefaultPrivacyCode: $e\n$st');
    }
  }

  Future<void> setNotifyNewViews(bool v) async {
    _notifyNewViews = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kNotifyViews, v);
    } catch (e, st) {
      debugPrint('setNotifyNewViews: $e\n$st');
    }
  }

  Future<void> setNotifyComments(bool v) async {
    _notifyComments = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kNotifyComments, v);
    } catch (e, st) {
      debugPrint('setNotifyComments: $e\n$st');
    }
  }

  Future<void> setNotifyLikes(bool v) async {
    _notifyLikes = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kNotifyLikes, v);
    } catch (e, st) {
      debugPrint('setNotifyLikes: $e\n$st');
    }
  }

  Future<void> setViewsNotificationThreshold(int v) async {
    _viewsNotificationThreshold = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kViewsThreshold, v);
    } catch (e, st) {
      debugPrint('setViewsNotificationThreshold: $e\n$st');
    }
  }

  Future<void> resetToDefaults() async {
    _autoPlayVideos = true;
    _showViewsCount = true;
    _videoQuality = VideoQuality.high;
    _enableWatermarkVideos = true;
    _locationBasedContent = true;
    _autoSaveDrafts = true;
    _defaultPrivacy = 'public';
    _notifyNewViews = true;
    _notifyComments = true;
    _notifyLikes = true;
    _viewsNotificationThreshold = 1000;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kAutoPlay, _autoPlayVideos);
      await p.setBool(_kShowViews, _showViewsCount);
      await p.setString(_kVideoQuality, _encodeQuality(_videoQuality));
      await p.setBool(_kWatermark, _enableWatermarkVideos);
      await p.setBool(_kLocationContent, _locationBasedContent);
      await p.setBool(_kAutoSave, _autoSaveDrafts);
      await p.setString(_kDefaultPrivacy, _defaultPrivacy);
      await p.setBool(_kNotifyViews, _notifyNewViews);
      await p.setBool(_kNotifyComments, _notifyComments);
      await p.setBool(_kNotifyLikes, _notifyLikes);
      await p.setInt(_kViewsThreshold, _viewsNotificationThreshold);
    } catch (e, st) {
      debugPrint('resetToDefaults: $e\n$st');
    }
  }
}
