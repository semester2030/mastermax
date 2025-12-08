import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/camera_config.dart';
import '../models/camera_result.dart';
import '../models/media_metadata.dart';
import 'watermark_service.dart';
import 'audio_service.dart';

class CameraService {
  late CameraController controller;
  final WatermarkService _watermarkService;
  final AudioService _audioService;
  CameraConfig _config;

  CameraService({
    required WatermarkService watermarkService,
    required AudioService audioService,
    CameraConfig? config,
  }) : _watermarkService = watermarkService,
       _audioService = audioService,
       _config = config ?? CameraConfig();

  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('No cameras found', 'Device has no cameras available');
    }

    controller = CameraController(
      cameras.first,
      ResolutionPreset.max,
      enableAudio: _config.enableAudio,
    );

    await controller.initialize();
  }

  Future<CameraResult?> captureImage() async {
    if (!controller.value.isInitialized) {
      throw CameraException('Camera not initialized', 'Please initialize camera first');
    }

    try {
      final XFile image = await controller.takePicture();
      final String? audioPath = _config.enableAudio ? await _audioService.recordAudio() : null;

      // Add watermark
      final String watermarkedPath = await _watermarkService.addWatermark(
        image.path,
        _config.watermarkText,
        _config.watermarkPosition,
        _config.watermarkOpacity,
        _config.watermarkColor,
        _config.watermarkSize,
      );

      // Get image dimensions
      final imageFile = await image.readAsBytes();
      final decodedImage = await decodeImageFromList(imageFile);

      return CameraResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: watermarkedPath,
        type: MediaType.image,
        timestamp: DateTime.now(),
        metadata: await _createMetadata(),
        dimensions: Size(decodedImage.width.toDouble(), decodedImage.height.toDouble()),
        fileSize: await image.length() / 1024, // Convert to KB
        audioPath: audioPath,
      );
    } catch (e, stackTrace) {
      debugPrint('Error capturing image: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<MediaMetadata> _createMetadata() async {
    return MediaMetadata(
      deviceModel: 'Test Device',
      latitude: 0.0,
      longitude: 0.0,
      cameraSettings: _getCameraSettings(),
      watermarkInfo: '${_config.watermarkText} - ${_config.watermarkPosition}',
      hasAudio: _config.enableAudio,
      createdBy: 'Test User',
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> _getCameraSettings() {
    return {
      'isInitialized': controller.value.isInitialized,
      'previewSize': {
        'width': controller.value.previewSize?.width,
        'height': controller.value.previewSize?.height,
      },
      'flashMode': controller.value.flashMode.toString(),
      'exposureMode': controller.value.exposureMode.toString(),
      'focusMode': controller.value.focusMode.toString(),
      'enableAudio': _config.enableAudio,
      'resolution': _config.resolution,
    };
  }

  void updateConfig(CameraConfig newConfig) {
    _config = newConfig;
    if (controller.value.isInitialized) {
      controller.setFlashMode(FlashMode.auto);
      // Update other camera settings based on config
    }
  }

  Future<void> dispose() async {
    await controller.dispose();
  }
} 