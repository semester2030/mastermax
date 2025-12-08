import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// طبقة الأمان للمصادقة - منفصلة تماماً عن المنطق الحالي
class AuthSecurityLayer {
  static final AuthSecurityLayer _instance = AuthSecurityLayer._internal();
  factory AuthSecurityLayer() => _instance;

  // المتغيرات الداخلية - لا تؤثر على الكود الحالي
  final _loginAttempts = <String, List<DateTime>>{};
  final _trustedDevices = <String, String>{};
  final _activeSessions = <String, DateTime>{};
  
  // تكوين قابل للتعديل
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
  static const Duration sessionTimeout = Duration(hours: 24);

  AuthSecurityLayer._internal();

  /// التحقق من محاولات تسجيل الدخول - لا يمنع التسجيل، فقط يسجل المحاولات
  Future<bool> checkLoginAttempt(String identifier) async {
    final now = DateTime.now();
    final attempts = _loginAttempts[identifier] ?? [];
    
    // إزالة المحاولات القديمة
    attempts.removeWhere(
      (attempt) => now.difference(attempt) > lockoutDuration
    );
    
    _loginAttempts[identifier] = attempts;
    
    // إضافة المحاولة الحالية
    attempts.add(now);
    
    return attempts.length <= maxLoginAttempts;
  }

  /// التحقق من الجهاز - يمكن تفعيله أو تعطيله بسهولة
  Future<bool> isDeviceTrusted(String userId, String deviceId) async {
    return _trustedDevices[userId] == deviceId;
  }

  /// إضافة جهاز موثوق - لا يؤثر على المنطق الحالي
  Future<void> addTrustedDevice(String userId, String deviceId) async {
    _trustedDevices[userId] = deviceId;
  }

  /// التحقق من صلاحية الجلسة - يمكن تجاهله في البداية
  Future<bool> isSessionValid(String sessionId) async {
    final lastActivity = _activeSessions[sessionId];
    if (lastActivity == null) return false;
    
    return DateTime.now().difference(lastActivity) <= sessionTimeout;
  }

  /// تحديث نشاط الجلسة - آمن وغير مؤثر
  Future<void> updateSessionActivity(String sessionId) async {
    _activeSessions[sessionId] = DateTime.now();
  }

  /// توليد رمز 2FA - يمكن استخدامه لاحقاً
  String generate2FACode() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode(random);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 6);
  }

  /// التحقق من صحة رمز 2FA - يمكن تفعيله تدريجياً
  Future<bool> verify2FACode(String storedCode, String inputCode) async {
    return storedCode == inputCode;
  }

  /// تنظيف البيانات القديمة - يعمل في الخلفية بدون تأثير
  Future<void> cleanup() async {
    final now = DateTime.now();
    
    // تنظيف محاولات تسجيل الدخول القديمة
    _loginAttempts.removeWhere((_, attempts) {
      attempts.removeWhere(
        (attempt) => now.difference(attempt) > lockoutDuration
      );
      return attempts.isEmpty;
    });
    
    // تنظيف الجلسات منتهية الصلاحية
    _activeSessions.removeWhere((_, lastActivity) {
      return now.difference(lastActivity) > sessionTimeout;
    });
  }

  /// إيقاف جميع الجلسات - آمن للاستخدام
  Future<void> invalidateAllSessions(String userId) async {
    _activeSessions.clear();
    _trustedDevices.remove(userId);
  }
} 