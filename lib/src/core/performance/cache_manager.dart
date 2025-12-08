import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../core/constants/app_constants.dart';
import '../utils/logger.dart';

class AppCacheManager {
  static final AppCacheManager _instance = AppCacheManager._internal();
  factory AppCacheManager() => _instance;
  AppCacheManager._internal();

  late SharedPreferences _prefs;
  late DefaultCacheManager _fileCache;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      _fileCache = DefaultCacheManager();
      _isInitialized = true;
      logInfo('Cache manager initialized successfully');
      
    } catch (e, stackTrace) {
      logError('Failed to initialize cache manager', e, stackTrace);
      rethrow;
    }
  }

  // دوال التعامل مع البيانات البسيطة باستخدام SharedPreferences
  Future<void> setString(String key, String value) async {
    await _checkInitialization();
    await _prefs.setString(_getKey(key), value);
  }

  Future<String?> getString(String key) async {
    await _checkInitialization();
    return _prefs.getString(_getKey(key));
  }

  Future<void> setInt(String key, int value) async {
    await _checkInitialization();
    await _prefs.setInt(_getKey(key), value);
  }

  Future<int?> getInt(String key) async {
    await _checkInitialization();
    return _prefs.getInt(_getKey(key));
  }

  Future<void> setDouble(String key, double value) async {
    await _checkInitialization();
    await _prefs.setDouble(_getKey(key), value);
  }

  Future<double?> getDouble(String key) async {
    await _checkInitialization();
    return _prefs.getDouble(_getKey(key));
  }

  Future<void> setBool(String key, bool value) async {
    await _checkInitialization();
    await _prefs.setBool(_getKey(key), value);
  }

  Future<bool?> getBool(String key) async {
    await _checkInitialization();
    return _prefs.getBool(_getKey(key));
  }

  Future<void> setStringList(String key, List<String> value) async {
    await _checkInitialization();
    await _prefs.setStringList(_getKey(key), value);
  }

  Future<List<String>?> getStringList(String key) async {
    await _checkInitialization();
    return _prefs.getStringList(_getKey(key));
  }

  Future<void> setObject(String key, Map<String, dynamic> value) async {
    await _checkInitialization();
    final jsonString = jsonEncode(value);
    await _prefs.setString(_getKey(key), jsonString);
  }

  Future<Map<String, dynamic>?> getObject(String key) async {
    await _checkInitialization();
    final jsonString = _prefs.getString(_getKey(key));
    if (jsonString == null) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  Future<void> setObjectList(String key, List<Map<String, dynamic>> value) async {
    await _checkInitialization();
    final jsonString = jsonEncode(value);
    await _prefs.setString(_getKey(key), jsonString);
  }

  Future<List<Map<String, dynamic>>?> getObjectList(String key) async {
    await _checkInitialization();
    final jsonString = _prefs.getString(_getKey(key));
    if (jsonString == null) return null;
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.cast<Map<String, dynamic>>();
  }

  Future<void> remove(String key) async {
    await _checkInitialization();
    await _prefs.remove(_getKey(key));
  }

  Future<void> clear() async {
    await _checkInitialization();
    await _prefs.clear();
  }

  Future<bool> containsKey(String key) async {
    await _checkInitialization();
    return _prefs.containsKey(_getKey(key));
  }

  Future<void> reload() async {
    await _checkInitialization();
    await _prefs.reload();
  }

  Future<Set<String>> getKeys() async {
    await _checkInitialization();
    return _prefs.getKeys();
  }

  // دوال التعامل مع الملفات الكبيرة
  Future<File?> getFile(String url) async {
    await _checkInitialization();
    try {
      final fileInfo = await _fileCache.getFileFromCache(url);
      return fileInfo?.file;
    } catch (e, stackTrace) {
      logError('Error getting file from cache: $url', e, stackTrace);
      return null;
    }
  }

  Future<File> downloadFile(String url) async {
    await _checkInitialization();
    try {
      final fileInfo = await _fileCache.downloadFile(url);
      return fileInfo.file;
    } catch (e, stackTrace) {
      logError('Error downloading file: $url', e, stackTrace);
      rethrow;
    }
  }

  Future<void> removeFile(String url) async {
    await _checkInitialization();
    try {
      await _fileCache.removeFile(url);
      logInfo('File removed from cache: $url');
    } catch (e, stackTrace) {
      logError('Error removing file from cache: $url', e, stackTrace);
    }
  }

  Future<void> clearCache() async {
    await _checkInitialization();
    try {
      // تنظيف SharedPreferences
      final keys = _prefs.getKeys().where((key) => 
        key.startsWith('${AppConstants.cachePrefix}_'));
      for (final key in keys) {
        await _prefs.remove(key);
      }

      // تنظيف الملفات
      await _fileCache.emptyCache();
      
      logInfo('Cache cleared successfully');
    } catch (e, stackTrace) {
      logError('Error clearing cache', e, stackTrace);
    }
  }

  Future<int> getCacheSize() async {
    await _checkInitialization();
    int totalSize = 0;

    try {
      // حجم البيانات في SharedPreferences
      final keys = _prefs.getKeys();
      for (final key in keys) {
        final value = _prefs.get(key);
        if (value != null) {
          if (value is String) {
            totalSize += value.length;
          } else if (value is bool) {
            totalSize += 1;
          } else if (value is int || value is double) {
            totalSize += 8;
          } else if (value is List<String>) {
            totalSize += value.join().length;
          }
        }
      }

      // نضيف حجم تقديري للملفات المخزنة (100 ميجابايت كحد أقصى)
      totalSize += 100 * 1024 * 1024;

    } catch (e, stackTrace) {
      logError('Error calculating cache size', e, stackTrace);
    }

    return totalSize;
  }

  Future<void> enforceMaxCacheSize() async {
    await _checkInitialization();
    try {
      final currentSize = await getCacheSize();
      if (currentSize > AppConstants.maxCacheSize) {
        await clearCache();
        logInfo('Cache cleared due to size limit (${currentSize ~/ 1024 ~/ 1024}MB > ${AppConstants.maxCacheSize ~/ 1024 ~/ 1024}MB)');
      }
    } catch (e, stackTrace) {
      logError('Error enforcing max cache size', e, stackTrace);
    }
  }

  Future<void> _checkInitialization() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  String _getKey(String key) {
    return '${AppConstants.cachePrefix}_$key';
  }
} 