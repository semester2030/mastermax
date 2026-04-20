import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات رفع الفيديو - Feature Flag للتحكم بين Firebase و Cloudflare
/// 
/// هذا الملف آمن 100% - لا يمس الكود الحالي
/// يمكنك تفعيل/تعطيل Cloudflare من هنا
class VideoUploadConfig {
  /// حد Cloudflare Stream للرفع multipart البسيط (بايت). فوق هذا الحجم يجب استخدام TUS.
  /// مرجع: https://developers.cloudflare.com/stream/uploading-videos/upload-video-file/
  static const int cloudflareBasicUploadMaxBytes = 200 * 1024 * 1024;

  static const String _useCloudflareKey = 'use_cloudflare_stream';
  static const String _cloudflareApiTokenKey = 'cloudflare_api_token';
  static const String _cloudflareAccountIdKey = 'cloudflare_account_id';
  static const String _cloudflareSubdomainKey = 'cloudflare_subdomain';

  /// التحقق من استخدام Cloudflare Stream
  /// 
  /// إذا كان `false` → يستخدم Firebase (الكود الحالي)
  /// إذا كان `true` → يستخدم Cloudflare Stream
  static Future<bool> shouldUseCloudflare() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_useCloudflareKey) ?? false; // افتراضياً: Firebase
    } catch (e) {
      // في حالة الخطأ، نستخدم Firebase (الأمان)
      return false;
    }
  }

  /// تفعيل/تعطيل Cloudflare Stream
  static Future<void> setUseCloudflare(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useCloudflareKey, value);
  }

  /// الحصول على API Token الخاص بـ Cloudflare
  static Future<String?> getCloudflareApiToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cloudflareApiTokenKey);
    } catch (e) {
      return null;
    }
  }

  /// حفظ API Token الخاص بـ Cloudflare
  static Future<void> setCloudflareApiToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cloudflareApiTokenKey, token);
  }

  /// الحصول على Account ID الخاص بـ Cloudflare
  static Future<String?> getCloudflareAccountId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cloudflareAccountIdKey);
    } catch (e) {
      return null;
    }
  }

  /// حفظ Account ID الخاص بـ Cloudflare
  static Future<void> setCloudflareAccountId(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cloudflareAccountIdKey, accountId);
  }

  /// الحصول على Customer Subdomain الخاص بـ Cloudflare
  static Future<String?> getCloudflareSubdomain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cloudflareSubdomainKey);
    } catch (e) {
      return null;
    }
  }

  /// حفظ Customer Subdomain الخاص بـ Cloudflare
  static Future<void> setCloudflareSubdomain(String subdomain) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cloudflareSubdomainKey, subdomain);
  }

  /// تهيئة إعدادات Cloudflare (استدعاء مرة واحدة)
  static Future<void> initializeCloudflareSettings({
    required String apiToken,
    required String accountId,
    required String subdomain,
  }) async {
    await setCloudflareApiToken(apiToken);
    await setCloudflareAccountId(accountId);
    await setCloudflareSubdomain(subdomain);
  }

  /// جاهزية الرفع عبر Cloudflare عند تفعيل الخيار **ومستخدم مسجّل** (التوكن على Cloud Functions فقط).
  static Future<bool> isCloudflareConfigured() async {
    if (!await shouldUseCloudflare()) return false;
    return FirebaseAuth.instance.currentUser != null;
  }

  /// إزالة التوكنات القديمة من الجهاز بعد الترحيل إلى Cloud Functions.
  static Future<void> clearLegacyCloudflareSecretsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cloudflareApiTokenKey);
    await prefs.remove(_cloudflareAccountIdKey);
  }
}
