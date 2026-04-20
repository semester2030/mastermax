import 'dart:io';
import 'package:flutter/material.dart';
import '../models/camera_result.dart';
import '../models/media_metadata.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_brand.dart';

class ThreeDService {
  final List<String> _capturedImages = [];
  final int requiredAngles = 12; // عدد الزوايا المطلوبة للنموذج ثلاثي الأبعاد
  bool _isCapturing = false;
  double _currentAngle = 0;

  bool get isCapturing => _isCapturing;
  int get capturedCount => _capturedImages.length;
  double get progress => _capturedImages.length / requiredAngles;
  double get currentAngle => _currentAngle;

  Future<void> startCapture() async {
    if (_isCapturing) return;
    _isCapturing = true;
    _capturedImages.clear();
    _currentAngle = 0;
  }

  Future<void> addImage(String imagePath) async {
    if (!_isCapturing) return;
    _capturedImages.add(imagePath);
    _currentAngle += 360 / requiredAngles;
  }

  Future<CameraResult?> finishCapture() async {
    if (!_isCapturing || _capturedImages.length < requiredAngles) return null;
    _isCapturing = false;

    try {
      final String modelPath = await _createModel();
      final modelDir = Directory(modelPath);
      final int fileSize = modelDir.statSync().size;
      
      return CameraResult(
        id: const Uuid().v4(),
        path: modelPath,
        type: MediaType.threeDimensional,
        timestamp: DateTime.now(),
        metadata: await _createMetadata(),
        dimensions: const Size(4096, 4096),
        fileSize: fileSize / 1024,
        additionalData: {
          'angles': requiredAngles,
          'angleStep': 360 / requiredAngles,
          'format': '3D_MODEL',
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Error creating 3D model: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<String> _createModel() async {
    final tempDir = await getTemporaryDirectory();
    final modelDir = await Directory('${tempDir.path}/3d_model').create(recursive: true);
    
    for (int i = 0; i < _capturedImages.length; i++) {
      final File sourceFile = File(_capturedImages[i]);
      if (await sourceFile.exists()) {
        final String fileName = '3d_part_$i.jpg';
        await sourceFile.copy('${modelDir.path}/$fileName');
      }
    }

    // إنشاء ملف وصفي للنموذج
    final modelDescriptor = {
      'version': '1.0',
      'type': '3D_MODEL',
      'images': _capturedImages.length,
      'angleStep': 360 / requiredAngles,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final descriptorFile = File('${modelDir.path}/model.json');
    await descriptorFile.writeAsString(modelDescriptor.toString());

    return modelDir.path;
  }

  Future<MediaMetadata> _createMetadata() async {
    return MediaMetadata(
      deviceModel: 'Test Device',
      latitude: 0.0,
      longitude: 0.0,
      cameraSettings: {
        'type': '3D',
        'imageCount': _capturedImages.length,
        'angleStep': 360 / requiredAngles,
        'resolution': '4096x4096',
      },
      watermarkInfo: '${AppBrand.displayName} - 3D Model',
      hasAudio: false,
      createdBy: 'Test User',
      createdAt: DateTime.now(),
    );
  }

  String getNextAngleGuide() {
    final remainingAngles = requiredAngles - _capturedImages.length;
    final nextAngle = _currentAngle + (360 / requiredAngles);
    return 'التقط $remainingAngles صور أخرى. قم بتدوير العنصر إلى $nextAngle درجة';
  }

  void cancelCapture() {
    _isCapturing = false;
    _capturedImages.clear();
    _currentAngle = 0;
  }

  Future<void> cleanup() async {
    for (final imagePath in _capturedImages) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e, stackTrace) {
        debugPrint('Error cleaning up 3D model images: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
    _capturedImages.clear();
    _currentAngle = 0;
  }
} 