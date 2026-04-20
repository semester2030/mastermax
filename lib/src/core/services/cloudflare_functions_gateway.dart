import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// استدعاءات Cloud Functions التي تحمل أسرار Cloudflare على الخادم فقط.
///
/// يجب أن تتطابق [region] مع `REGION` في `functions/index.js`.
class CloudflareFunctionsGateway {
  CloudflareFunctionsGateway._();

  static const String region = 'europe-west1';

  static FirebaseFunctions get _fns =>
      FirebaseFunctions.instanceFor(region: region);

  static HttpsCallable _callable(String name) => _fns.httpsCallable(
        name,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 120),
        ),
      );

  static Future<void> _ensureSignedIn() async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('يجب تسجيل الدخول قبل رفع الوسائط عبر الخادم.');
    }
  }

  static Future<Map<String, dynamic>> createStreamDirectUpload({String? title}) async {
    await _ensureSignedIn();
    final res = await _callable('createStreamDirectUpload').call<Map<String, dynamic>>({
      if (title != null && title.isNotEmpty) 'title': title,
    });
    return _asStringKeyedMap(res.data, 'createStreamDirectUpload');
  }

  static Future<Map<String, dynamic>> getStreamVideoInfo(String videoId) async {
    await _ensureSignedIn();
    final res = await _callable('getStreamVideoInfo').call<Map<String, dynamic>>({
      'videoId': videoId,
    });
    return _asStringKeyedMap(res.data, 'getStreamVideoInfo');
  }

  static Future<void> deleteStreamVideo(String videoId) async {
    await _ensureSignedIn();
    await _callable('deleteStreamVideo').call<Map<String, dynamic>>({
      'videoId': videoId,
    });
  }

  static Future<Map<String, dynamic>> createImagesDirectUpload() async {
    await _ensureSignedIn();
    final res = await _callable('createImagesDirectUpload').call<Map<String, dynamic>>({});
    return _asStringKeyedMap(res.data, 'createImagesDirectUpload');
  }

  static Future<void> deleteImageFromCloudflare(String imageId) async {
    await _ensureSignedIn();
    await _callable('deleteImageFromCloudflare').call<Map<String, dynamic>>({
      'imageId': imageId,
    });
  }

  static Map<String, dynamic> _asStringKeyedMap(Object? raw, String op) {
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    throw StateError('استجابة $op ليست خريطة');
  }
}
