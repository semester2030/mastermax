import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../../../core/utils/logger.dart';

/// خدمة إدارة صور العقارات
class PropertyImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final _uuid = const Uuid();

  /// التقاط صورة من الكاميرا
  Future<File?> captureImage() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo != null) {
        return File(photo.path);
      }
      return null;
    } catch (e) {
      logError('Error capturing image', e);
      rethrow;
    }
  }

  /// اختيار صور من المعرض
  Future<List<File>> pickImages() async {
    try {
      final List<XFile> photos = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return photos.map((photo) => File(photo.path)).toList();
    } catch (e) {
      logError('Error picking images', e);
      rethrow;
    }
  }

  /// رفع صورة واحدة
  Future<String> uploadImage(File imageFile, String propertyId) async {
    try {
      final String fileName = '${_uuid.v4()}${path.extension(imageFile.path)}';
      final Reference ref = _storage.ref()
          .child('properties')
          .child(propertyId)
          .child(fileName);

      final UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/${path.extension(imageFile.path).substring(1)}'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      logError('Error uploading image', e);
      rethrow;
    }
  }

  /// رفع مجموعة صور
  Future<List<String>> uploadImages(List<File> imageFiles, String propertyId) async {
    try {
      final List<String> urls = [];
      for (final imageFile in imageFiles) {
        final url = await uploadImage(imageFile, propertyId);
        urls.add(url);
      }
      return urls;
    } catch (e) {
      logError('Error uploading images', e);
      rethrow;
    }
  }

  /// حذف صورة
  Future<void> deleteImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      logError('Error deleting image', e);
      rethrow;
    }
  }

  /// حذف جميع صور العقار
  Future<void> deleteAllPropertyImages(String propertyId) async {
    try {
      final Reference ref = _storage.ref().child('properties').child(propertyId);
      final ListResult result = await ref.listAll();
      for (final Reference item in result.items) {
        await item.delete();
      }
    } catch (e) {
      logError('Error deleting property images', e);
      rethrow;
    }
  }

  /// تحديث ترتيب الصور
  Future<List<String>> reorderImages(List<String> imageUrls, int oldIndex, int newIndex) async {
    try {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String item = imageUrls.removeAt(oldIndex);
      imageUrls.insert(newIndex, item);
      return imageUrls;
    } catch (e) {
      logError('Error reordering images', e);
      rethrow;
    }
  }
} 