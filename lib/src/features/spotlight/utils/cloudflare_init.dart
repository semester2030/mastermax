import '../config/video_upload_config.dart';

/// التحقق من أن Cloudflare Stream مفعّل والمستخدم جاهز للرفع عبر Cloud Functions.
Future<bool> isCloudflareReady() async {
  final isConfigured = await VideoUploadConfig.isCloudflareConfigured();
  final isEnabled = await VideoUploadConfig.shouldUseCloudflare();
  return isConfigured && isEnabled;
}
