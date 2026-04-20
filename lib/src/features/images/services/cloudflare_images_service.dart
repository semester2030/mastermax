import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../../../core/services/cloudflare_functions_gateway.dart';
import '../../../core/services/media_failure_log_service.dart';
import '../config/image_upload_config.dart';

/// نتيجة رفع الصورة إلى Cloudflare Images
class CloudflareImageResult {
  final bool success;
  final String? imageId;
  final String? imageUrl;
  final String? error;
  final Map<String, dynamic>? metadata;

  CloudflareImageResult({
    required this.success,
    this.imageId,
    this.imageUrl,
    this.error,
    this.metadata,
  });
}

/// رفع الصور عبر **Cloud Functions** (رابط رفع مباشر من Cloudflare دون توكن في التطبيق).
class CloudflareImagesService {
  CloudflareImagesService();

  final Logger _logger = Logger();

  static Future<CloudflareImagesService?> fromConfig() async {
    try {
      if (!await ImageUploadConfig.shouldUseCloudflare()) return null;
      if (FirebaseAuth.instance.currentUser == null) return null;
      if (!await ImageUploadConfig.isCloudflareConfigured()) return null;
      return CloudflareImagesService();
    } catch (_) {
      return null;
    }
  }

  /// رفع صورة إلى Cloudflare Images
  Future<CloudflareImageResult> uploadImage({
    required File imageFile,
    Function(double progress)? onProgress,
  }) async {
    try {
      _logger.d('Starting Cloudflare Images upload (via Functions): ${imageFile.path}');

      if (!await imageFile.exists()) {
        await MediaFailureLogService.log(
          mediaKind: 'image',
          context: 'cloudflare_images',
          errorMessage: 'Image file does not exist',
          detail: imageFile.path,
        );
        return CloudflareImageResult(
          success: false,
          error: 'Image file does not exist',
        );
      }

      final direct = await CloudflareFunctionsGateway.createImagesDirectUpload();
      final uploadURL = direct['uploadURL'] as String?;
      final imagesHash = direct['imagesHash'] as String?;
      if (uploadURL == null || uploadURL.isEmpty || imagesHash == null || imagesHash.isEmpty) {
        return CloudflareImageResult(
          success: false,
          error: 'استجابة غير صالحة من الخادم (رابط رفع الصورة).',
        );
      }

      await ImageUploadConfig.setCloudflareImagesHash(imagesHash);

      final uri = Uri.parse(uploadURL);
      final request = http.MultipartRequest('POST', uri);
      final imageStream = imageFile.openRead();
      final imageLength = await imageFile.length();

      final multipartFile = http.MultipartFile(
        'file',
        imageStream,
        imageLength,
        filename: imageFile.path.split('/').last,
      );
      request.files.add(multipartFile);

      if (onProgress != null) {
        onProgress(0.05);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (onProgress != null) {
        onProgress(1.0);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        if (responseData['success'] == true) {
          final result = responseData['result'] as Map<String, dynamic>;
          final imageId = result['id'] as String;
          final imageUrl = 'https://imagedelivery.net/$imagesHash/$imageId/public';

          return CloudflareImageResult(
            success: true,
            imageId: imageId,
            imageUrl: imageUrl,
            metadata: result,
          );
        }

        final errors = responseData['errors'] as List<dynamic>?;
        final errorMessage = errors?.isNotEmpty == true
            ? errors!.first.toString()
            : 'Unknown error';

        await MediaFailureLogService.log(
          mediaKind: 'image',
          context: 'cloudflare_images_api',
          errorMessage: errorMessage,
          detail: response.body.length > 1200 ? '${response.body.substring(0, 1200)}…' : response.body,
        );

        return CloudflareImageResult(
          success: false,
          error: errorMessage,
        );
      }

      final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
      final errors = errorData?['errors'] as List<dynamic>?;
      final errorMessage = errors?.isNotEmpty == true
          ? errors!.first.toString()
          : 'Upload failed with status ${response.statusCode}';

      await MediaFailureLogService.log(
        mediaKind: 'image',
        context: 'cloudflare_images_http',
        errorMessage: '$errorMessage (HTTP ${response.statusCode})',
        detail: response.body.length > 1200 ? '${response.body.substring(0, 1200)}…' : response.body,
      );

      return CloudflareImageResult(
        success: false,
        error: errorMessage,
      );
    } catch (e, stackTrace) {
      _logger.e('Error uploading image to Cloudflare Images', error: e, stackTrace: stackTrace);
      await MediaFailureLogService.log(
        mediaKind: 'image',
        context: 'cloudflare_images_exception',
        errorMessage: e.toString(),
        detail: imageFile.path,
      );
      return CloudflareImageResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// حذف صورة من Cloudflare Images
  Future<bool> deleteImage(String imageId) async {
    try {
      await CloudflareFunctionsGateway.deleteImageFromCloudflare(imageId);
      return true;
    } catch (e) {
      _logger.e('Error deleting image from Cloudflare Images', error: e);
      return false;
    }
  }

  /// استخراج Image ID من URL
  static String? extractImageIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host == 'imagedelivery.net') {
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 2) {
          return pathSegments[1];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
