import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../../../core/config/app_config.dart';
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

  /// مهلة صريحة لطلب الرفع الفعلي إلى Cloudflare (يمنع التعليق بلا نهاية).
  static const Duration uploadTimeout = Duration(seconds: 120);

  static const String _uploadDraftsCollection = 'upload_drafts';
  static const String _draftEntityType = 'cloudflare_image';

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
    // One draft id per call — prevents duplicate drafts within the same upload.
    DocumentReference<Map<String, dynamic>>? draftRef;

    try {
      _logger.d(
        'Starting Cloudflare Images upload (via Functions): ${imageFile.path}',
      );

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

      // PR-025: optional expand — create pending then move to uploading before CF I/O.
      draftRef = await _beginUploadDraft();
      await _markDraftUploading(draftRef);

      final direct = await CloudflareFunctionsGateway.createImagesDirectUpload();
      final uploadURL = direct['uploadURL'] as String?;
      final imagesHash = direct['imagesHash'] as String?;
      if (uploadURL == null ||
          uploadURL.isEmpty ||
          imagesHash == null ||
          imagesHash.isEmpty) {
        const err = 'استجابة غير صالحة من الخادم (رابط رفع الصورة).';
        await _markDraftFailed(draftRef, err);
        return CloudflareImageResult(
          success: false,
          error: err,
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

      // PR-020: bound the actual Cloudflare multipart upload (send + body read).
      final response = await () async {
        final streamedResponse = await request.send();
        return http.Response.fromStream(streamedResponse);
      }().timeout(
        uploadTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Image upload timed out after ${uploadTimeout.inSeconds}s',
          );
        },
      );

      if (onProgress != null) {
        onProgress(1.0);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        if (responseData['success'] == true) {
          final result = responseData['result'] as Map<String, dynamic>;
          final imageId = result['id'] as String;
          final imageUrl =
              'https://imagedelivery.net/$imagesHash/$imageId/public';

          await _markDraftCompleted(draftRef, imageId);

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
          detail: response.body.length > 1200
              ? '${response.body.substring(0, 1200)}…'
              : response.body,
        );

        await _markDraftFailed(draftRef, errorMessage);

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
        detail: response.body.length > 1200
            ? '${response.body.substring(0, 1200)}…'
            : response.body,
      );

      await _markDraftFailed(draftRef, errorMessage);

      return CloudflareImageResult(
        success: false,
        error: errorMessage,
      );
    } on TimeoutException catch (e, stackTrace) {
      _logger.e(
        'Cloudflare Images upload timed out',
        error: e,
        stackTrace: stackTrace,
      );
      await MediaFailureLogService.log(
        mediaKind: 'image',
        context: 'cloudflare_images_timeout',
        errorMessage: e.message ?? 'upload timeout',
        detail: imageFile.path,
      );
      final msg =
          'انتهت مهلة رفع الصورة (${uploadTimeout.inSeconds} ثانية). تحقق من الاتصال وحاول مرة أخرى.';
      await _markDraftFailed(draftRef, msg);
      return CloudflareImageResult(
        success: false,
        error: msg,
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Error uploading image to Cloudflare Images',
        error: e,
        stackTrace: stackTrace,
      );
      await MediaFailureLogService.log(
        mediaKind: 'image',
        context: 'cloudflare_images_exception',
        errorMessage: e.toString(),
        detail: imageFile.path,
      );
      await _markDraftFailed(draftRef, e.toString());
      return CloudflareImageResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// PR-025: create at most one `pending` draft for this upload call.
  Future<DocumentReference<Map<String, dynamic>>?> _beginUploadDraft() async {
    if (!AppConfig.uploadOutbox) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    try {
      final ref =
          FirebaseFirestore.instance.collection(_uploadDraftsCollection).doc();
      await ref.set({
        'ownerId': uid,
        'entityType': _draftEntityType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'attemptCount': 0,
        'uploadedImageIds': <String>[],
        'lastError': '',
      });
      return ref;
    } catch (e) {
      // Expand-only: never block the existing upload path.
      _logger.w('UPLOAD_OUTBOX draft create skipped: $e');
      return null;
    }
  }

  Future<void> _markDraftUploading(
    DocumentReference<Map<String, dynamic>>? ref,
  ) async {
    if (ref == null) return;
    try {
      await ref.update({
        'status': 'uploading',
        'attemptCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastError': '',
      });
    } catch (e) {
      _logger.w('UPLOAD_OUTBOX draft uploading skipped: $e');
    }
  }

  Future<void> _markDraftCompleted(
    DocumentReference<Map<String, dynamic>>? ref,
    String imageId,
  ) async {
    if (ref == null) return;
    try {
      await ref.update({
        'status': 'completed',
        'uploadedImageIds': [imageId],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastError': '',
      });
    } catch (e) {
      _logger.w('UPLOAD_OUTBOX draft completed skipped: $e');
    }
  }

  Future<void> _markDraftFailed(
    DocumentReference<Map<String, dynamic>>? ref,
    String error,
  ) async {
    if (ref == null) return;
    try {
      await ref.update({
        'status': 'failed',
        'lastError': _sanitizeDraftError(error),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.w('UPLOAD_OUTBOX draft failed skipped: $e');
    }
  }

  /// Safe lastError for PR-025A rules (≤800) — no tokens / upload URLs / raw paths.
  static String _sanitizeDraftError(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '[url]');
    s = s.replaceAll(RegExp(r'Bearer\s+\S+', caseSensitive: false), '[redacted]');
    if (s.length > 800) {
      s = '${s.substring(0, 800)}…';
    }
    return s;
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
