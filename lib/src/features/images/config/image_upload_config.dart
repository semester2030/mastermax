import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات رفع الصور - Feature Flag للتحكم بين Firebase Storage و Cloudflare Images
/// 
/// هذا الملف آمن 100% - لا يمس الكود الحالي
/// يمكنك تفعيل/تعطيل Cloudflare Images من هنا
class ImageUploadConfig {
  // ✅ مفاتيح منفصلة تماماً عن VideoUploadConfig لتجنب التعارض
  static const String _useCloudflareKey = 'use_cloudflare_images';
  static const String _cloudflareApiTokenKey = 'cloudflare_images_api_token'; // ✅ منفصل عن Stream
  static const String _cloudflareAccountIdKey = 'cloudflare_images_account_id'; // ✅ منفصل عن Stream
  static const String _cloudflareImagesHashKey = 'cloudflare_images_hash';

  /// التحقق من استخدام Cloudflare Images
  /// 
  /// إذا كان `false` → يستخدم Firebase Storage (الكود الحالي)
  /// إذا كان `true` → يستخدم Cloudflare Images
  static Future<bool> shouldUseCloudflare() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_useCloudflareKey) ?? false; // افتراضياً: Firebase
    } catch (e) {
      // في حالة الخطأ، نستخدم Firebase (الأمان)
      return false;
    }
  }

  /// تفعيل/تعطيل Cloudflare Images
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

  /// الحصول على Images Hash (لإنشاء URLs)
  static Future<String?> getCloudflareImagesHash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cloudflareImagesHashKey);
    } catch (e) {
      return null;
    }
  }

  /// حفظ Images Hash
  static Future<void> setCloudflareImagesHash(String hash) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cloudflareImagesHashKey, hash);
  }

  /// تهيئة إعدادات Cloudflare Images (استدعاء مرة واحدة)
  static Future<void> initializeCloudflareSettings({
    required String apiToken,
    required String accountId,
    required String imagesHash,
  }) async {
    await setCloudflareApiToken(apiToken);
    await setCloudflareAccountId(accountId);
    await setCloudflareImagesHash(imagesHash);
  }

  /// جاهزية رفع الصور عبر Cloudflare عند التفعيل **ومستخدم مسجّل** (التوكن على Cloud Functions فقط).
  static Future<bool> isCloudflareConfigured() async {
    if (!await shouldUseCloudflare()) return false;
    return FirebaseAuth.instance.currentUser != null;
  }

  static Future<void> clearLegacyCloudflareSecretsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cloudflareApiTokenKey);
    await prefs.remove(_cloudflareAccountIdKey);
  }
}
