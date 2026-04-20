import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/utils/logger.dart';
import '../../images/config/image_upload_config.dart';
import '../../images/services/cloudflare_images_service.dart';

/// خدمة إدارة صور السيارات
/// 
/// ✅ الصور تُرفع إلى Cloudflare Images فقط (NOT Firebase Storage)
class CarImageService {

  /// رفع صورة واحدة
  Future<String> uploadImage(File imageFile, String carId) async {
    try {
      // التحقق من أن المستخدم مسجل دخول
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول أولاً لرفع الصور');
      }

      // ✅ التحقق الإلزامي: Cloudflare Images يجب أن يكون مفعل ومُهيأ
      final useCloudflare = await ImageUploadConfig.shouldUseCloudflare();
      if (!useCloudflare) {
        throw Exception(
          'Cloudflare Images غير مفعل. يرجى تفعيل Cloudflare Images أولاً.\n'
          'لا يمكن رفع الصور إلى Firebase Storage.',
        );
      }

      final isConfigured = await ImageUploadConfig.isCloudflareConfigured();
      if (!isConfigured) {
        throw Exception(
          'Cloudflare Images غير مُهيأ بشكل كامل.\n'
          'يرجى التحقق من: API Token, Account ID, و Images Hash.\n'
          'لا يمكن رفع الصور إلى Firebase Storage.',
        );
      }

      // ✅ رفع إلى Cloudflare Images فقط (إلزامي)
      logInfo('🚀 Starting image upload to Cloudflare Images (NOT Firebase)...');
      final cloudflareService = await CloudflareImagesService.fromConfig();
      if (cloudflareService == null) {
        throw Exception(
          'فشل في تهيئة خدمة Cloudflare Images.\n'
          'يرجى التحقق من الإعدادات.\n'
          'لا يمكن رفع الصور إلى Firebase Storage.',
        );
      }

      final result = await cloudflareService.uploadImage(imageFile: imageFile);
      if (result.success && result.imageUrl != null) {
        logInfo('✅✅✅ SUCCESS: Car image uploaded to Cloudflare Images ONLY');
        logInfo('✅ Image URL: ${result.imageUrl}');
        logInfo('✅ Image ID: ${result.imageId}');
        logInfo('✅✅✅ PROOF: Image stored in Cloudflare Images (NOT Firebase Storage)');
        return result.imageUrl!;
      } else {
        throw Exception(
          'فشل رفع الصورة إلى Cloudflare Images: ${result.error}\n'
          'لا يمكن رفع الصور إلى Firebase Storage.',
        );
      }
    } catch (e) {
      logError('Error uploading car image', e);
      rethrow;
    }
  }

  /// رفع مجموعة صور
  Future<List<String>> uploadImages(List<File> imageFiles, String carId) async {
    try {
      final List<String> urls = [];
      for (final imageFile in imageFiles) {
        final url = await uploadImage(imageFile, carId);
        urls.add(url);
      }
      return urls;
    } catch (e) {
      logError('Error uploading car images', e);
      rethrow;
    }
  }

  /// حذف صورة
  Future<void> deleteImage(String imageUrl) async {
    try {
      // ✅ التحقق من استخدام Cloudflare Images
      final useCloudflare = await ImageUploadConfig.shouldUseCloudflare();
      
      if (useCloudflare && imageUrl.contains('imagedelivery.net')) {
        // ✅ حذف من Cloudflare Images
        final imageId = CloudflareImagesService.extractImageIdFromUrl(imageUrl);
        if (imageId != null) {
          final cloudflareService = await CloudflareImagesService.fromConfig();
          if (cloudflareService != null) {
            final deleted = await cloudflareService.deleteImage(imageId);
            if (deleted) {
              logInfo('✅ Car image deleted from Cloudflare Images: $imageId');
              return;
            } else {
              throw Exception('فشل حذف الصورة من Cloudflare Images');
            }
          }
        }
      }

      // ✅ للصور القديمة من Firebase Storage (إذا كانت موجودة)
      if (imageUrl.contains('firebasestorage.googleapis.com')) {
        logInfo('⚠️ Old Firebase Storage image detected - cannot delete from here');
        logInfo('⚠️ Please delete manually from Firebase Console if needed');
        return;
      }

      throw Exception('لا يمكن حذف الصورة - URL غير معروف');
    } catch (e) {
      logError('Error deleting car image', e);
      rethrow;
    }
  }

  /// حذف جميع صور السيارة
  /// 
  /// ⚠️ ملاحظة: هذه الدالة لحذف الصور القديمة من Firebase Storage فقط
  /// ✅ الصور الجديدة في Cloudflare Images يجب حذفها من Cloudflare Dashboard
  Future<void> deleteAllCarImages(String carId) async {
    try {
      logInfo('⚠️ deleteAllCarImages: This function is for old Firebase Storage images only');
      logInfo('⚠️ New images in Cloudflare Images must be deleted from Cloudflare Dashboard');
      // ✅ لا يوجد كود لحذف من Firebase Storage - الصور الجديدة في Cloudflare Images
    } catch (e) {
      logError('Error deleting car images', e);
      rethrow;
    }
  }
}

