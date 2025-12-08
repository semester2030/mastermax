import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/security/data_encryptor.dart';
import '../../core/monitoring/performance_monitor.dart';

class NetworkClient {
  static final NetworkClient _instance = NetworkClient._internal();
  factory NetworkClient() => _instance;
  
  final http.Client _client = http.Client();
  final Connectivity _connectivity = Connectivity();
  final DataEncryptor _encryptor = DataEncryptor();
  final PerformanceMonitor _monitor = PerformanceMonitor();
  
  // إعدادات إعادة المحاولة والتحسين
  static const int maxRetries = 3;
  static const int retryDelay = 1; // بالثواني
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration cacheExpiration = Duration(minutes: 5);
  static const int maxCacheSize = 50 * 1024 * 1024; // 50 MB
  
  // التخزين المؤقت للطلبات
  final Map<String, _CachedResponse> _cache = {};
  Timer? _cacheCleanupTimer;
  int _currentCacheSize = 0;
  
  NetworkClient._internal() {
    _startCacheCleanup();
  }

  void _startCacheCleanup() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _cleanCache();
    });
  }

  void _cleanCache() {
    final now = DateTime.now();
    _cache.removeWhere((_, cached) => 
      now.difference(cached.timestamp) > cacheExpiration);
  }

  Future<bool> hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<Map<String, dynamic>> request({
    required String url,
    required String method,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    int retryCount = 0,
    bool useCache = true,
  }) async {
    try {
      _monitor.startMeasurement('network_request_$url');

      // التحقق من التخزين المؤقت للطلبات GET
      if (method.toUpperCase() == 'GET' && useCache) {
        final cachedResponse = _getCachedResponse(url);
        if (cachedResponse != null) {
          _monitor.endMeasurement('network_request_$url');
          return cachedResponse;
        }
      }

      if (!await hasConnection()) {
        throw NetworkException('لا يوجد اتصال بالإنترنت');
      }

      final requestHeaders = {
        'Content-Type': 'application/json',
        ...?headers,
      };

      if (requiresAuth) {
        final token = _encryptor.decrypt('auth_token');
        if (token.isNotEmpty) {
          requestHeaders['Authorization'] = 'Bearer $token';
        }
      }

      final response = await _executeRequest(
        url: url,
        method: method,
        headers: requestHeaders,
        body: body,
      ).timeout(requestTimeout);

      _monitor.endMeasurement('network_request_$url');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        
        // تخزين مؤقت للطلبات GET
        if (method.toUpperCase() == 'GET' && useCache) {
          _cacheResponse(url, responseData);
        }
        
        return responseData;
      } 
      
      // معالجة الأخطاء مع إعادة المحاولة
      if (_shouldRetry(response.statusCode) && retryCount < maxRetries) {
        await Future.delayed(Duration(seconds: retryDelay * (retryCount + 1)));
        return request(
          url: url,
          method: method,
          headers: headers,
          body: body,
          requiresAuth: requiresAuth,
          retryCount: retryCount + 1,
          useCache: useCache,
        );
      }

      throw _handleError(response);
    } catch (e) {
      _monitor.endMeasurement('network_request_$url');
      
      if (e is NetworkException) {
        rethrow;
      }
      
      if (retryCount < maxRetries) {
        await Future.delayed(Duration(seconds: retryDelay * (retryCount + 1)));
        return request(
          url: url,
          method: method,
          headers: headers,
          body: body,
          requiresAuth: requiresAuth,
          retryCount: retryCount + 1,
          useCache: useCache,
        );
      }
      
      throw NetworkException('فشل الطلب بعد $maxRetries محاولات: $e');
    }
  }

  Map<String, dynamic>? _getCachedResponse(String url) {
    final cached = _cache[url];
    if (cached != null && 
        DateTime.now().difference(cached.timestamp) <= cacheExpiration) {
      return cached.data;
    }
    return null;
  }

  void _cacheResponse(String url, Map<String, dynamic> data) {
    final String jsonData = json.encode(data);
    final int dataSize = jsonData.length;

    // التحقق من حجم الذاكرة المؤقتة
    if (_currentCacheSize + dataSize > maxCacheSize) {
      _cleanOldestCache();
    }

    _cache[url] = _CachedResponse(data);
    _currentCacheSize += dataSize;
  }

  void _cleanOldestCache() {
    if (_cache.isEmpty) return;
    
    // حذف أقدم البيانات المخزنة
    final oldest = _cache.entries
      .reduce((a, b) => 
        a.value.timestamp.isBefore(b.value.timestamp) ? a : b);
    
    final String jsonData = json.encode(oldest.value.data);
    _currentCacheSize -= jsonData.length;
    _cache.remove(oldest.key);
  }

  Future<http.Response> _executeRequest({
    required String url,
    required String method,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) async {
    switch (method.toUpperCase()) {
      case 'GET':
        return _client.get(Uri.parse(url), headers: headers);
      case 'POST':
        return _client.post(
          Uri.parse(url),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      case 'PUT':
        return _client.put(
          Uri.parse(url),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      case 'DELETE':
        return _client.delete(Uri.parse(url), headers: headers);
      default:
        throw NetworkException('طريقة الطلب غير مدعومة');
    }
  }

  bool _shouldRetry(int statusCode) {
    return statusCode == 408 || // Request Timeout
           statusCode == 429 || // Too Many Requests
           statusCode >= 500;   // Server Errors
  }

  Exception _handleError(http.Response response) {
    switch (response.statusCode) {
      case 401:
        return UnauthorizedException('غير مصرح');
      case 403:
        return ForbiddenException('غير مسموح');
      case 404:
        return NotFoundException('الصفحة غير موجودة');
      case 429:
        return RateLimitException('تم تجاوز حد الطلبات');
      default:
        return NetworkException(
          'حدث خطأ في الطلب: ${response.statusCode}\n${response.body}',
        );
    }
  }

  Stream<bool> get connectionStream => _connectivity.onConnectivityChanged
    .map((List<ConnectivityResult> results) => !results.contains(ConnectivityResult.none));

  Map<String, dynamic> getPerformanceReport() {
    return {
      'cache_size': _currentCacheSize,
      'cache_items': _cache.length,
      'cache_hit_rate': _calculateCacheHitRate(),
      'average_response_time': _monitor.getAverageResponseTime(),
      'memory_usage': _currentCacheSize / maxCacheSize * 100,
      'connection_status': _connectivity.checkConnectivity(),
    };
  }

  double _calculateCacheHitRate() {
    final totalRequests = _monitor.getTotalRequests();
    if (totalRequests == 0) return 0.0;
    return _cache.length / totalRequests * 100;
  }

  void dispose() {
    _cacheCleanupTimer?.cancel();
    _cache.clear();
    _client.close();
  }
}

class _CachedResponse {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  _CachedResponse(this.data) : timestamp = DateTime.now();
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}

class UnauthorizedException extends NetworkException {
  UnauthorizedException(super.message);
}

class ForbiddenException extends NetworkException {
  ForbiddenException(super.message);
}

class NotFoundException extends NetworkException {
  NotFoundException(super.message);
}

class RateLimitException extends NetworkException {
  RateLimitException(super.message);
} 