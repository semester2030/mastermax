import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../../../../core/utils/logger.dart';

/// خدمة رفع الصور الملتقطة بالكاميرا إلى Firebase Storage
class CameraStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  /// رفع صورة واحدة إلى Firebase Storage
  Future<String> uploadImage(File imageFile, {String? folder}) async {
    try {
      // التحقق من أن المستخدم مسجل دخول
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول أولاً لرفع الصور');
      }

      final userId = currentUser.uid;
      final String fileName = '${_uuid.v4()}${path.extension(imageFile.path)}';
      final String contentType = path.extension(imageFile.path).substring(1);
      
      // المسار: images/{userId}/camera/{folder}/{fileName}
      final String storagePath = folder != null
          ? 'images/$userId/camera/$folder/$fileName'
          : 'images/$userId/camera/$fileName';
      
      final Reference ref = _storage.ref().child(storagePath);

      // إضافة metadata للمستخدم
      final metadata = SettableMetadata(
        contentType: 'image/$contentType',
        customMetadata: {
          'userId': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'source': 'camera',
        },
      );

      final UploadTask uploadTask = ref.putFile(imageFile, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      logInfo('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      logError('Error uploading camera image', e);
      rethrow;
    }
  }

  /// رفع صورة بانورامية
  Future<String> uploadPanoramaImage(File imageFile) async {
    return uploadImage(imageFile, folder: 'panorama');
  }

  /// رفع صورة 3D
  Future<String> upload3DImage(File imageFile) async {
    return uploadImage(imageFile, folder: '3d');
  }

  /// رفع مجموعة صور
  Future<List<String>> uploadImages(List<File> imageFiles, {String? folder}) async {
    try {
      final List<String> urls = [];
      for (final imageFile in imageFiles) {
        final url = await uploadImage(imageFile, folder: folder);
        urls.add(url);
      }
      return urls;
    } catch (e) {
      logError('Error uploading camera images', e);
      rethrow;
    }
  }

  /// حذف صورة من Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      logInfo('Image deleted successfully');
    } catch (e) {
      logError('Error deleting camera image', e);
      rethrow;
    }
  }
}

