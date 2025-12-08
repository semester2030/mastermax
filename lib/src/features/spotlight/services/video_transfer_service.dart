import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class VideoTransferService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> transferVideoToStorage(String documentId) async {
    try {
      // جلب بيانات الفيديو من Firestore
      final videoDoc = await _firestore
          .collection('spotlight_videos')
          .doc(documentId)
          .get();
      
      if (!videoDoc.exists) {
        throw Exception('Video document not found');
      }

      final data = videoDoc.data()!;
      final String type = data['type'];
      
      // تحديد مسار الفيديو في المشروع
      String videoPath;
      if (type == 'realEstate') {
        videoPath = 'assets/videos/real_estate/property3_video.mp4';
      } else {
        videoPath = 'assets/videos/cars/car1_video.mp4';
      }

      // نسخ الفيديو إلى مجلد مؤقت
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_video.mp4');
      
      // قراءة الفيديو من assets
      final ByteData videoData = await rootBundle.load(videoPath);
      await tempFile.writeAsBytes(videoData.buffer.asUint8List());

      // رفع الفيديو إلى Firebase Storage
      final videoRef = _storage.ref().child('videos/$documentId.mp4');
      await videoRef.putFile(tempFile);

      // الحصول على رابط التحميل الجديد
      final newVideoUrl = await videoRef.getDownloadURL();

      // تحديث الرابط في Firestore
      await _firestore
          .collection('spotlight_videos')
          .doc(documentId)
          .update({
        'url': newVideoUrl,
      });

      // حذف الملف المؤقت
      await tempFile.delete();
    } catch (e) {
      print('Error transferring video: $e');
      rethrow;
    }
  }
} 