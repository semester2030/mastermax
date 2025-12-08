import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/utils/logger.dart';

/// نظام تسجيل الأحداث الأمنية
class SecurityAuditLog {
  static final SecurityAuditLog _instance = SecurityAuditLog._internal();
  factory SecurityAuditLog() => _instance;

  final FirebaseFirestore _firestore;
  final DeviceInfoPlugin _deviceInfo;
  
  SecurityAuditLog._internal()
      : _firestore = FirebaseFirestore.instance,
        _deviceInfo = DeviceInfoPlugin();

  /// تسجيل حدث أمني
  Future<void> logSecurityEvent({
    required String userId,
    required SecurityEventType eventType,
    required String details,
    String? ip,
  }) async {
    try {
      // جمع معلومات الجهاز
      final deviceInfo = await _getDeviceInfo();
      
      // جمع معلومات التطبيق
      final packageInfo = await PackageInfo.fromPlatform();
      
      // إنشاء السجل
      final logEntry = {
        'userId': userId,
        'eventType': eventType.toString(),
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceInfo': deviceInfo,
        'appInfo': {
          'version': packageInfo.version,
          'buildNumber': packageInfo.buildNumber,
        },
        'ip': ip,
      };

      // حفظ السجل في Firestore
      await _firestore
          .collection('security_logs')
          .doc()
          .set(logEntry);
          
    } catch (e) {
      // في حالة الخطأ، نحاول الحفظ في مخزن احتياطي
      await _saveToBackupStorage({
        'error': e.toString(),
        'userId': userId,
        'eventType': eventType.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// جمع معلومات الجهاز
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final deviceInfo = await _deviceInfo.deviceInfo;
      return {
        'platform': deviceInfo.data['platform'] ?? 'unknown',
        'model': deviceInfo.data['model'] ?? 'unknown',
        'deviceId': deviceInfo.data['id'] ?? 'unknown',
        'manufacturer': deviceInfo.data['manufacturer'] ?? 'unknown',
      };
    } catch (e) {
      return {
        'error': 'Failed to get device info: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// حفظ السجل في مخزن احتياطي عند فشل Firestore
  Future<void> _saveToBackupStorage(Map<String, dynamic> log) async {
    try {
      // سنكتفي بتسجيل الخطأ حتى يتم تنفيذ التخزين الاحتياطي
      logError('Failed to save security log to Firestore');
    } catch (e) {
      // تجاهل الخطأ في التخزين الاحتياطي لتجنب الحلقة المفرغة
      return;
    }
  }

  /// الحصول على سجلات مستخدم معين
  Future<List<Map<String, dynamic>>> getUserLogs(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('security_logs')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// الحصول على آخر الأحداث الأمنية
  Future<List<Map<String, dynamic>>> getRecentEvents({
    int limit = 50,
    SecurityEventType? eventType,
  }) async {
    try {
      var query = _firestore
          .collection('security_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (eventType != null) {
        query = query.where('eventType', isEqualTo: eventType.toString());
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      return [];
    }
  }
}

/// أنواع الأحداث الأمنية
enum SecurityEventType {
  login,
  logout,
  failedLogin,
  passwordChange,
  deviceAdded,
  deviceRemoved,
  twoFactorEnabled,
  twoFactorDisabled,
  accountLocked,
  accountUnlocked,
  suspiciousActivity,
} 