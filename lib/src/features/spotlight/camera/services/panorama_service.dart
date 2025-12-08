import 'dart:io';
import 'package:flutter/material.dart';
import '../models/camera_result.dart';
import '../models/media_metadata.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class PanoramaService {
  final List<String> _capturedImages = [];
  final int requiredImages = 8; // عدد الصور المطلوبة لتكوين صورة 360 درجة
  bool _isCapturing = false;

  bool get isCapturing => _isCapturing;
  int get capturedCount => _capturedImages.length;
  double get progress => _capturedImages.length / requiredImages;

  Future<void> startCapture() async {
    if (_isCapturing) return;
    _isCapturing = true;
    _capturedImages.clear();
  }

  Future<void> addImage(String imagePath) async {
    if (!_isCapturing) return;
    _capturedImages.add(imagePath);
  }

  Future<CameraResult?> finishCapture() async {
    if (!_isCapturing || _capturedImages.length < requiredImages) return null;
    _isCapturing = false;

    try {
      final String stitchedImagePath = await _stitchImages();
      
      return CameraResult(
        id: const Uuid().v4(),
        path: stitchedImagePath,
        type: MediaType.panoramic,
        timestamp: DateTime.now(),
        metadata: await _createMetadata(),
        dimensions: const Size(4096, 2048), // حجم قياسي للصور البانورامية
        fileSize: await File(stitchedImagePath).length() / 1024, // تحويل إلى KB
      );
    } catch (e, stackTrace) {
      debugPrint('Error creating panorama: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<String> _stitchImages() async {
    // في التطبيق الفعلي، هنا سيتم استخدام خوارزمية لدمج الصور
    final tempDir = await getTemporaryDirectory();
    final panoramaDir = await Directory('${tempDir.path}/panorama').create(recursive: true);
    
    for (int i = 0; i < _capturedImages.length; i++) {
      final File sourceFile = File(_capturedImages[i]);
      if (await sourceFile.exists()) {
        final String fileName = 'panorama_part_$i.jpg';
        await sourceFile.copy('${panoramaDir.path}/$fileName');
      }
    }

    return '${panoramaDir.path}/panorama_result.jpg';
  }

  Future<MediaMetadata> _createMetadata() async {
    return MediaMetadata(
      deviceModel: 'Test Device',
      latitude: 0.0,
      longitude: 0.0,
      cameraSettings: {
        'type': 'panoramic',
        'imageCount': _capturedImages.length,
        'resolution': '4096x2048',
      },
      watermarkInfo: 'Master Max - 360° Panorama',
      hasAudio: false,
      createdBy: 'Test User',
      createdAt: DateTime.now(),
    );
  }

  void cancelCapture() {
    _isCapturing = false;
    _capturedImages.clear();
  }

  Future<void> cleanup() async {
    for (final imagePath in _capturedImages) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e, stackTrace) {
        debugPrint('Error cleaning up panorama images: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
    _capturedImages.clear();
  }
} 