import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/logger.dart';
import 'cloudflare_images_service.dart';
import '../config/image_upload_config.dart';

/// نتيجة نقل صورة واحدة
class ImageMigrationResult {
  final bool success;
  final String? oldUrl;
  final String? newUrl;
  final String? error;

  ImageMigrationResult({
    required this.success,
    this.oldUrl,
    this.newUrl,
    this.error,
  });
}

/// نتيجة نقل جميع الصور
class BulkMigrationResult {
  final int totalImages;
  final int migratedImages;
  final int failedImages;
  final List<String> errors;

  BulkMigrationResult({
    required this.totalImages,
    required this.migratedImages,
    required this.failedImages,
    required this.errors,
  });
}

/// خدمة نقل الصور من Firebase Storage إلى Cloudflare Images
class MigrateImagesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// نقل صورة واحدة من Firebase Storage إلى Cloudflare Images
  Future<ImageMigrationResult> migrateSingleImage(String firebaseImageUrl) async {
    try {
      // ✅ التحقق من أن الصورة من Firebase Storage
      if (!firebaseImageUrl.contains('firebasestorage.googleapis.com')) {
        return ImageMigrationResult(
          success: false,
          oldUrl: firebaseImageUrl,
          error: 'الصورة ليست من Firebase Storage',
        );
      }

      // ✅ التحقق من أن Cloudflare Images مُهيأ
      final isConfigured = await ImageUploadConfig.isCloudflareConfigured();
      if (!isConfigured) {
        return ImageMigrationResult(
          success: false,
          oldUrl: firebaseImageUrl,
          error: 'Cloudflare Images غير مُهيأ',
        );
      }

      logInfo('🔄 Starting migration: $firebaseImageUrl');

      // ✅ تحميل الصورة من Firebase Storage
      final http.Response response = await http.get(Uri.parse(firebaseImageUrl));
      if (response.statusCode != 200) {
        return ImageMigrationResult(
          success: false,
          oldUrl: firebaseImageUrl,
          error: 'فشل تحميل الصورة من Firebase Storage: ${response.statusCode}',
        );
      }

      // ✅ حفظ الصورة مؤقتاً
      final tempFile = File('${Directory.systemTemp.path}/migrate_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(response.bodyBytes);

      // ✅ رفع الصورة إلى Cloudflare Images
      final cloudflareService = await CloudflareImagesService.fromConfig();
      if (cloudflareService == null) {
        return ImageMigrationResult(
          success: false,
          oldUrl: firebaseImageUrl,
          error: 'فشل تهيئة خدمة Cloudflare Images',
        );
      }

      final uploadResult = await cloudflareService.uploadImage(imageFile: tempFile);
      
      // ✅ حذف الملف المؤقت
      try {
        await tempFile.delete();
      } catch (e) {
        logError('Failed to delete temp file', e);
      }

      if (uploadResult.success && uploadResult.imageUrl != null) {
        logInfo('✅✅✅ SUCCESS: Image migrated to Cloudflare Images');
        logInfo('✅ Old URL: $firebaseImageUrl');
        logInfo('✅ New URL: ${uploadResult.imageUrl}');
        
        return ImageMigrationResult(
          success: true,
          oldUrl: firebaseImageUrl,
          newUrl: uploadResult.imageUrl,
        );
      } else {
        return ImageMigrationResult(
          success: false,
          oldUrl: firebaseImageUrl,
          error: uploadResult.error ?? 'فشل رفع الصورة إلى Cloudflare Images',
        );
      }
    } catch (e) {
      logError('Error migrating image', e);
      return ImageMigrationResult(
        success: false,
        oldUrl: firebaseImageUrl,
        error: e.toString(),
      );
    }
  }

  /// نقل جميع صور سيارة واحدة
  Future<BulkMigrationResult> migrateCarImages(String carId) async {
    try {
      logInfo('🚀 Starting migration for car: $carId');

      // ✅ جلب بيانات السيارة
      final carDoc = await _firestore.collection('cars').doc(carId).get();
      if (!carDoc.exists) {
        return BulkMigrationResult(
          totalImages: 0,
          migratedImages: 0,
          failedImages: 0,
          errors: ['السيارة غير موجودة'],
        );
      }

      final carData = carDoc.data() as Map<String, dynamic>;
      final images = (carData['images'] as List<dynamic>?)?.cast<String>() ?? [];
      final mainImage = carData['mainImage'] as String?;

      final List<String> allImageUrls = [];
      if (mainImage != null && mainImage.isNotEmpty) {
        allImageUrls.add(mainImage);
      }
      allImageUrls.addAll(images);

      // ✅ تصفية الصور من Firebase Storage فقط
      final firebaseImages = allImageUrls
          .where((url) => url.contains('firebasestorage.googleapis.com'))
          .toSet()
          .toList();

      if (firebaseImages.isEmpty) {
        logInfo('✅ No Firebase Storage images found for car: $carId');
        return BulkMigrationResult(
          totalImages: 0,
          migratedImages: 0,
          failedImages: 0,
          errors: [],
        );
      }

      logInfo('📸 Found ${firebaseImages.length} Firebase Storage images to migrate');

      // ✅ نقل كل صورة
      final List<String> newImageUrls = [];
      final List<String> errors = [];
      int migratedCount = 0;
      int failedCount = 0;

      for (final oldUrl in firebaseImages) {
        final result = await migrateSingleImage(oldUrl);
        if (result.success && result.newUrl != null) {
          newImageUrls.add(result.newUrl!);
          migratedCount++;
        } else {
          errors.add('${result.oldUrl}: ${result.error}');
          failedCount++;
        }
      }

      // ✅ تحديث URLs في Firestore
      if (newImageUrls.isNotEmpty) {
        final updatedImages = images.map((url) {
          if (firebaseImages.contains(url)) {
            final index = firebaseImages.indexOf(url);
            return index < newImageUrls.length ? newImageUrls[index] : url;
          }
          return url;
        }).toList();

        String? updatedMainImage = mainImage;
        if (mainImage != null && firebaseImages.contains(mainImage)) {
          final index = firebaseImages.indexOf(mainImage);
          if (index < newImageUrls.length) {
            updatedMainImage = newImageUrls[index];
          }
        }

        await _firestore.collection('cars').doc(carId).update({
          'images': updatedImages,
          'mainImage': updatedMainImage,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        logInfo('✅✅✅ Updated car document with new Cloudflare Images URLs');
      }

      return BulkMigrationResult(
        totalImages: firebaseImages.length,
        migratedImages: migratedCount,
        failedImages: failedCount,
        errors: errors,
      );
    } catch (e) {
      logError('Error migrating car images', e);
      return BulkMigrationResult(
        totalImages: 0,
        migratedImages: 0,
        failedImages: 0,
        errors: [e.toString()],
      );
    }
  }

  /// نقل جميع صور عقار واحد
  Future<BulkMigrationResult> migratePropertyImages(String propertyId) async {
    try {
      logInfo('🚀 Starting migration for property: $propertyId');

      // ✅ جلب بيانات العقار
      final propertyDoc = await _firestore.collection('properties').doc(propertyId).get();
      if (!propertyDoc.exists) {
        return BulkMigrationResult(
          totalImages: 0,
          migratedImages: 0,
          failedImages: 0,
          errors: ['العقار غير موجود'],
        );
      }

      final propertyData = propertyDoc.data() as Map<String, dynamic>;
      final images = (propertyData['images'] as List<dynamic>?)?.cast<String>() ?? [];

      // ✅ تصفية الصور من Firebase Storage فقط
      final firebaseImages = images
          .where((url) => url.contains('firebasestorage.googleapis.com'))
          .toSet()
          .toList();

      if (firebaseImages.isEmpty) {
        logInfo('✅ No Firebase Storage images found for property: $propertyId');
        return BulkMigrationResult(
          totalImages: 0,
          migratedImages: 0,
          failedImages: 0,
          errors: [],
        );
      }

      logInfo('📸 Found ${firebaseImages.length} Firebase Storage images to migrate');

      // ✅ نقل كل صورة
      final List<String> newImageUrls = [];
      final List<String> errors = [];
      int migratedCount = 0;
      int failedCount = 0;

      for (final oldUrl in firebaseImages) {
        final result = await migrateSingleImage(oldUrl);
        if (result.success && result.newUrl != null) {
          newImageUrls.add(result.newUrl!);
          migratedCount++;
        } else {
          errors.add('${result.oldUrl}: ${result.error}');
          failedCount++;
        }
      }

      // ✅ تحديث URLs في Firestore
      if (newImageUrls.isNotEmpty) {
        final updatedImages = images.map((url) {
          if (firebaseImages.contains(url)) {
            final index = firebaseImages.indexOf(url);
            return index < newImageUrls.length ? newImageUrls[index] : url;
          }
          return url;
        }).toList();

        await _firestore.collection('properties').doc(propertyId).update({
          'images': updatedImages,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        logInfo('✅✅✅ Updated property document with new Cloudflare Images URLs');
      }

      return BulkMigrationResult(
        totalImages: firebaseImages.length,
        migratedImages: migratedCount,
        failedImages: failedCount,
        errors: errors,
      );
    } catch (e) {
      logError('Error migrating property images', e);
      return BulkMigrationResult(
        totalImages: 0,
        migratedImages: 0,
        failedImages: 0,
        errors: [e.toString()],
      );
    }
  }

  /// نقل جميع صور جميع السيارات
  Future<BulkMigrationResult> migrateAllCarsImages() async {
    try {
      logInfo('🚀🚀🚀 Starting migration for ALL cars...');

      final carsSnapshot = await _firestore.collection('cars').get();
      final List<String> allErrors = [];
      int totalMigrated = 0;
      int totalFailed = 0;
      int totalImages = 0;

      for (final carDoc in carsSnapshot.docs) {
        final result = await migrateCarImages(carDoc.id);
        totalImages += result.totalImages;
        totalMigrated += result.migratedImages;
        totalFailed += result.failedImages;
        allErrors.addAll(result.errors);
      }

      logInfo('✅✅✅ Migration completed for all cars');
      logInfo('📊 Total images: $totalImages');
      logInfo('✅ Migrated: $totalMigrated');
      logInfo('❌ Failed: $totalFailed');

      return BulkMigrationResult(
        totalImages: totalImages,
        migratedImages: totalMigrated,
        failedImages: totalFailed,
        errors: allErrors,
      );
    } catch (e) {
      logError('Error migrating all cars images', e);
      return BulkMigrationResult(
        totalImages: 0,
        migratedImages: 0,
        failedImages: 0,
        errors: [e.toString()],
      );
    }
  }

  /// نقل جميع صور جميع العقارات
  Future<BulkMigrationResult> migrateAllPropertiesImages() async {
    try {
      logInfo('🚀🚀🚀 Starting migration for ALL properties...');

      final propertiesSnapshot = await _firestore.collection('properties').get();
      final List<String> allErrors = [];
      int totalMigrated = 0;
      int totalFailed = 0;
      int totalImages = 0;

      for (final propertyDoc in propertiesSnapshot.docs) {
        final result = await migratePropertyImages(propertyDoc.id);
        totalImages += result.totalImages;
        totalMigrated += result.migratedImages;
        totalFailed += result.failedImages;
        allErrors.addAll(result.errors);
      }

      logInfo('✅✅✅ Migration completed for all properties');
      logInfo('📊 Total images: $totalImages');
      logInfo('✅ Migrated: $totalMigrated');
      logInfo('❌ Failed: $totalFailed');

      return BulkMigrationResult(
        totalImages: totalImages,
        migratedImages: totalMigrated,
        failedImages: totalFailed,
        errors: allErrors,
      );
    } catch (e) {
      logError('Error migrating all properties images', e);
      return BulkMigrationResult(
        totalImages: 0,
        migratedImages: 0,
        failedImages: 0,
        errors: [e.toString()],
      );
    }
  }
}
