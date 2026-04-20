import 'dart:io';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:tusc/tusc.dart';

import '../../../core/services/cloudflare_functions_gateway.dart';
import '../config/video_upload_config.dart';

/// يمرّر تقدّم رفع البايتات (0…1) لـ [onProgress] دون تغيير محتوى البث.
Stream<List<int>> _meteredUploadStream(
  Stream<List<int>> source,
  int totalBytes,
  void Function(double)? onProgress,
) async* {
  if (totalBytes <= 0) {
    onProgress?.call(0.0);
    await for (final chunk in source) {
      yield chunk;
    }
    onProgress?.call(1.0);
    return;
  }
  var sent = 0;
  onProgress?.call(0.0);
  await for (final chunk in source) {
    sent += chunk.length;
    if (sent > totalBytes) sent = totalBytes;
    onProgress?.call((sent / totalBytes).clamp(0.0, 0.999));
    yield chunk;
  }
  onProgress?.call(1.0);
}

/// نتيجة رفع الفيديو إلى Cloudflare Stream
class CloudflareVideoResult {
  final bool success;
  final String? videoId;
  final String? playbackUrl;
  final String? thumbnailUrl;
  final String? error;
  final Map<String, dynamic>? metadata;

  CloudflareVideoResult({
    required this.success,
    this.videoId,
    this.playbackUrl,
    this.thumbnailUrl,
    this.error,
    this.metadata,
  });
}

/// رفع Stream عبر **Cloud Functions** (رابط رفع مباشر من Cloudflare دون توكن في التطبيق).
class CloudflareStreamService {
  CloudflareStreamService();

  final Logger _logger = Logger();

  static Future<CloudflareStreamService?> fromConfig() async {
    try {
      if (!await VideoUploadConfig.shouldUseCloudflare()) return null;
      if (FirebaseAuth.instance.currentUser == null) return null;
      if (!await VideoUploadConfig.isCloudflareConfigured()) return null;
      return CloudflareStreamService();
    } catch (_) {
      return null;
    }
  }

  /// رفع فيديو إلى Cloudflare Stream
  Future<CloudflareVideoResult> uploadVideo({
    required File videoFile,
    String? title,
    Function(double progress)? onProgress,
  }) async {
    try {
      _logger.d('Starting Cloudflare Stream upload (via Functions): ${videoFile.path}');

      if (!await videoFile.exists()) {
        return CloudflareVideoResult(
          success: false,
          error: 'Video file does not exist',
        );
      }

      final videoLength = await videoFile.length();
      final direct = await CloudflareFunctionsGateway.createStreamDirectUpload(
        title: title,
      );
      final uploadURL = direct['uploadURL'] as String?;
      final uid = direct['uid'] as String?;
      final customerSubdomain = direct['customerSubdomain'] as String?;
      if (uploadURL == null || uid == null || customerSubdomain == null || uploadURL.isEmpty) {
        return CloudflareVideoResult(
          success: false,
          error: 'استجابة غير صالحة من الخادم (رابط الرفع).',
        );
      }

      await VideoUploadConfig.setCloudflareSubdomain(customerSubdomain);

      if (videoLength > VideoUploadConfig.cloudflareBasicUploadMaxBytes) {
        return _uploadVideoTus(
          videoFile: videoFile,
          videoLength: videoLength,
          uploadURL: uploadURL,
          uid: uid,
          customerSubdomain: customerSubdomain,
          title: title,
          onProgress: onProgress,
        );
      }

      final uri = Uri.parse(uploadURL);
      final request = http.MultipartRequest('POST', uri);
      final meteredStream = _meteredUploadStream(
        videoFile.openRead(),
        videoLength,
        onProgress,
      );
      final multipartFile = http.MultipartFile(
        'file',
        meteredStream,
        videoLength,
        filename: videoFile.path.split('/').last,
      );
      request.files.add(multipartFile);
      // رابط الرفع المباشر من direct_upload لا يعتمد meta في الطلب (العنوان يُمرَّر عند إنشاء الرابط من الخادم).

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          throw TimeoutException('Upload timeout after 10 minutes');
        },
      );

      final responseBody = await streamedResponse.stream.bytesToString();
      final status = streamedResponse.statusCode;
      final trimmed = responseBody.trim();

      // Cloudflare توثّق أن الرفع الناجح لـ uploadURL يعيد 200 فقط؛ شكل الجسم ليس مضموناً أن يكون JSON API v4.
      // لذلك نعتمد على [uid] القادم من createStreamDirectUpload عندما يكون الجسم فارغاً أو غير JSON.
      if (status == 200 || status == 201) {
        if (trimmed.isEmpty) {
          _logger.d('Cloudflare basic upload: HTTP $status empty body — using uid from direct_upload');
          return _basicUploadSuccessFromUid(
            uid: uid,
            customerSubdomain: customerSubdomain,
            result: null,
          );
        }

        Map<String, dynamic>? responseData;
        try {
          final decoded = jsonDecode(trimmed);
          responseData = decoded is Map<String, dynamic> ? decoded : null;
        } catch (_) {
          _logger.w(
            'Cloudflare basic upload: HTTP $status non-JSON body (len=${trimmed.length}) — using uid from direct_upload',
          );
          return _basicUploadSuccessFromUid(
            uid: uid,
            customerSubdomain: customerSubdomain,
            result: null,
          );
        }

        if (responseData != null && responseData['success'] == false) {
          final errorMessage = responseData['errors']?[0]?['message'] ??
              'رفض Cloudflare Stream (HTTP $status)';
          return CloudflareVideoResult(success: false, error: errorMessage.toString());
        }

        if (responseData != null && responseData['success'] == true) {
          final result = responseData['result'] as Map<String, dynamic>?;
          return _basicUploadSuccessFromUid(
            uid: uid,
            customerSubdomain: customerSubdomain,
            result: result,
          );
        }

        // JSON بلا success صريح (أشكال قديمة/بديلة) — ما دام 200 نعتبر الرفع ناجحاً بالـ uid المعروف.
        final looseResult = responseData?['result'];
        if (looseResult is Map<String, dynamic>) {
          return _basicUploadSuccessFromUid(
            uid: uid,
            customerSubdomain: customerSubdomain,
            result: looseResult,
          );
        }
        return _basicUploadSuccessFromUid(
          uid: uid,
          customerSubdomain: customerSubdomain,
          result: null,
        );
      }

      // أخطاء 4xx/5xx: حاول قراءة JSON للرسالة وإلا أظهر بادئة الجسم (غالباً HTML عند 502/403).
      Map<String, dynamic>? errMap;
      if (trimmed.isNotEmpty) {
        try {
          final d = jsonDecode(trimmed);
          errMap = d is Map<String, dynamic> ? d : null;
        } catch (_) {}
      }
      final fromJson = errMap?['errors']?[0]?['message']?.toString();
      final preview = trimmed.length > 280 ? '${trimmed.substring(0, 280)}…' : trimmed;
      final errorMessage = fromJson ??
          (preview.isNotEmpty && !preview.startsWith('{')
              ? 'HTTP $status — استجابة غير متوقعة من رفع الفيديو (تحقق من الحجم ≤200MB والرابط لمرة واحدة).'
              : 'HTTP $status');
      return CloudflareVideoResult(success: false, error: errorMessage);
    } on TimeoutException catch (e) {
      return CloudflareVideoResult(success: false, error: 'Upload timeout: ${e.message}');
    } catch (e) {
      _logger.e('Cloudflare upload error: $e');
      return CloudflareVideoResult(success: false, error: e.toString());
    }
  }

  CloudflareVideoResult _basicUploadSuccessFromUid({
    required String uid,
    required String customerSubdomain,
    Map<String, dynamic>? result,
  }) {
    final videoId = (result?['uid'] ?? uid) as String;
    final playbackUrl =
        'https://$customerSubdomain.cloudflarestream.com/$videoId/manifest/video.m3u8';
    String? thumbnailUrl;
    if (result != null && result['thumbnail'] is String) {
      thumbnailUrl = result['thumbnail'] as String?;
    }
    return CloudflareVideoResult(
      success: true,
      videoId: videoId,
      playbackUrl: playbackUrl,
      thumbnailUrl: thumbnailUrl,
      metadata: result,
    );
  }

  Future<CloudflareVideoResult> _uploadVideoTus({
    required File videoFile,
    required int videoLength,
    required String uploadURL,
    required String uid,
    required String customerSubdomain,
    String? title,
    Function(double progress)? onProgress,
  }) async {
    const chunkBytes = 50 * 1024 * 1024;
    final client = TusClient(
      url: uploadURL,
      file: XFile(videoFile.path),
      chunkSize: chunkBytes,
      headers: const {},
      timeout: const Duration(minutes: 15),
      metadata: (title != null && title.isNotEmpty) ? {'name': title} : null,
    );

    try {
      _logger.d(
        'Cloudflare TUS upload (~${(videoLength / (1024 * 1024)).toStringAsFixed(1)} MB)...',
      );
      await client.startUpload(
        onProgress: (count, total, _) {
          if (onProgress != null && total > 0) {
            onProgress(count / total);
          }
        },
      );

      final videoId = _cloudflareUidFromTusLocation(client.uploadUrl) ?? uid;
      final playbackUrl =
          'https://$customerSubdomain.cloudflarestream.com/$videoId/manifest/video.m3u8';

      String? thumbnailUrl;
      try {
        final info = await getVideoInfo(videoId);
        if (info != null && info['thumbnail'] is String) {
          thumbnailUrl = info['thumbnail'] as String;
        }
      } catch (_) {}

      return CloudflareVideoResult(
        success: true,
        videoId: videoId,
        playbackUrl: playbackUrl,
        thumbnailUrl: thumbnailUrl,
      );
    } on ProtocolException catch (e) {
      final body = e.response.body;
      return CloudflareVideoResult(
        success: false,
        error: body.isNotEmpty ? body : e.message,
      );
    } catch (e) {
      return CloudflareVideoResult(success: false, error: e.toString());
    }
  }

  String? _cloudflareUidFromTusLocation(String uploadLocation) {
    try {
      final u = Uri.parse(uploadLocation);
      final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
      final i = segs.indexOf('stream');
      if (i >= 0 && i + 1 < segs.length) {
        return segs[i + 1];
      }
      if (segs.isNotEmpty) {
        return segs.last;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getVideoInfo(String videoId) async {
    try {
      final data = await CloudflareFunctionsGateway.getStreamVideoInfo(videoId);
      return data['result'] as Map<String, dynamic>?;
    } catch (e) {
      _logger.e('Error getting video info: $e');
      return null;
    }
  }

  /// [spotlightDocId] = معرّف وثيقة `spotlight_videos` في Firestore.
  Future<bool> deleteSpotlightVideo({required String spotlightDocId}) async {
    try {
      await CloudflareFunctionsGateway.deleteStreamVideo(spotlightDocId);
      return true;
    } catch (e) {
      _logger.e('Error deleting video: $e');
      return false;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
