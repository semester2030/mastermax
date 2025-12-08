import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
// import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';  // تم تعليقه
import 'package:package_info_plus/package_info_plus.dart';
import 'security_encryption.dart';

/// نظام حماية التطبيق
class AppProtection {
  static final AppProtection _instance = AppProtection._internal();
  factory AppProtection() => _instance;

  final SecurityEncryption _encryption = SecurityEncryption();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // مدة صلاحية التوكن
  static const Duration _csrfTokenValidity = Duration(minutes: 30);
  
  AppProtection._internal();

  /// التحقق من سلامة التطبيق
  Future<AppIntegrityResult> verifyAppIntegrity() async {
    try {
      // التحقق من Root/Jailbreak - معطل مؤقتاً
      /* 
      final isJailbroken = await FlutterJailbreakDetection.jailbroken;
      if (isJailbroken) {
        return AppIntegrityResult(
          isValid: false,
          reason: 'تم اكتشاف محاولة اختراق الجهاز',
        );
      }
      */

      // التحقق من المحاكي
      final isEmulator = await _isEmulator();
      if (isEmulator) {
        return AppIntegrityResult(
          isValid: false,
          reason: 'لا يمكن استخدام التطبيق على محاكي',
        );
      }

      // التحقق من إصدار التطبيق
      final isValidVersion = await _verifyAppVersion();
      if (!isValidVersion) {
        return AppIntegrityResult(
          isValid: false,
          reason: 'يرجى تحديث التطبيق إلى أحدث إصدار',
        );
      }

      return AppIntegrityResult(isValid: true);
    } catch (e) {
      return AppIntegrityResult(
        isValid: false,
        reason: 'فشل التحقق من سلامة التطبيق',
      );
    }
  }

  /// حماية ضد هجمات CSRF
  Future<String> generateCSRFToken() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final token = base64Url.encode(bytes);
    
    // تشفير التوكن مع الطابع الزمني
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final combined = '$token:$timestamp';
    return _encryption.encryptSensitiveData(combined);
  }

  /// التحقق من صحة توكن CSRF
  Future<bool> validateCSRFToken(String encryptedToken) async {
    try {
      final decrypted = await _encryption.decryptSensitiveData(encryptedToken);
      final parts = decrypted.split(':');
      if (parts.length != 2) return false;

      final timestamp = int.tryParse(parts[1]);
      if (timestamp == null) return false;

      final tokenTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      // التحقق من صلاحية التوكن
      return now.difference(tokenTime) <= _csrfTokenValidity;
    } catch (e) {
      return false;
    }
  }

  /// التحقق من المحاكي
  Future<bool> _isEmulator() async {
    final deviceInfo = await _deviceInfo.deviceInfo;
    
    if (deviceInfo.data['isPhysicalDevice'] == false) {
      return true;
    }
    
    // فحوصات إضافية للمحاكي
    final fingerprint = deviceInfo.data['fingerprint']?.toString() ?? '';
    final model = deviceInfo.data['model']?.toString() ?? '';
    final manufacturer = deviceInfo.data['manufacturer']?.toString() ?? '';
    
    return fingerprint.contains('generic') ||
           model.contains('sdk') ||
           manufacturer.contains('Genymotion');
  }

  /// التحقق من إصدار التطبيق
  Future<bool> _verifyAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // التحقق من أقل إصدار مطلوب
      const minimumRequiredVersion = '1.0.0';
      
      return _compareVersions(currentVersion, minimumRequiredVersion) >= 0;
    } catch (e) {
      return false;
    }
  }

  /// مقارنة الإصدارات
  int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();
    
    for (var i = 0; i < 3; i++) {
      final v1 = v1Parts[i];
      final v2 = v2Parts[i];
      if (v1 > v2) return 1;
      if (v1 < v2) return -1;
    }
    
    return 0;
  }

  /// التحقق من صحة التوقيع
  Future<bool> verifySignature(String data, String signature) async {
    try {
      // سنحتفظ بالسلوك الحالي حتى يتم تنفيذ التحقق من التوقيع
      return true;
    } catch (e) {
      return false;
    }
  }

  /// توليد بصمة للجهاز
  Future<String> generateDeviceFingerprint() async {
    final deviceInfo = await _deviceInfo.deviceInfo;
    final packageInfo = await PackageInfo.fromPlatform();
    
    final fingerprintData = {
      'deviceId': deviceInfo.data['id'],
      'model': deviceInfo.data['model'],
      'manufacturer': deviceInfo.data['manufacturer'],
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
    };
    
    final jsonString = json.encode(fingerprintData);
    final bytes = utf8.encode(jsonString);
    final hash = sha256.convert(bytes);
    
    return hash.toString();
  }
}

/// نتيجة التحقق من سلامة التطبيق
class AppIntegrityResult {
  final bool isValid;
  final String? reason;

  AppIntegrityResult({
    required this.isValid,
    this.reason,
  });
} 