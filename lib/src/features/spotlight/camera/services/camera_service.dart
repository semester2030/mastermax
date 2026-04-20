import 'dart:async';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/camera_config.dart';
import '../models/camera_result.dart';
import '../models/media_metadata.dart';
import 'watermark_service.dart';
import 'audio_service.dart';
import '../../../../core/constants/app_brand.dart';

class CameraService {
  CameraController? controller; // ✅ Changed from late to nullable for safer initialization
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

  Future<bool> initialize() async {
    try {
      // التحقق من حالة الصلاحيات أولاً
      var cameraStatus = await Permission.camera.status;
      debugPrint('Initial camera permission status: $cameraStatus');
      debugPrint('isGranted: ${cameraStatus.isGranted}');
      debugPrint('isDenied: ${cameraStatus.isDenied}');
      debugPrint('isPermanentlyDenied: ${cameraStatus.isPermanentlyDenied}');
      debugPrint('isLimited: ${cameraStatus.isLimited}');
      debugPrint('isRestricted: ${cameraStatus.isRestricted}');
      
      // إذا كانت الصلاحيات ممنوحة بالفعل، نتابع مباشرة
      if (cameraStatus.isGranted) {
        debugPrint('✅ Camera permission already granted, proceeding...');
      } else if (cameraStatus.isPermanentlyDenied) {
        // إذا كانت الصلاحيات مرفوضة بشكل دائم، نحتاج فتح الإعدادات
        debugPrint('⚠️ Camera permission permanently denied');
        debugPrint('⚠️ User needs to enable camera in Settings > Privacy & Security > Camera > ${AppBrand.displayName}');
        // نفتح الإعدادات تلقائياً وننتظر
        debugPrint('Opening app settings...');
        final opened = await openAppSettings();
        debugPrint('Settings opened: $opened');
        
        // انتظار قليل ثم إعادة التحقق
        await Future.delayed(const Duration(seconds: 2));
        cameraStatus = await Permission.camera.status;
        debugPrint('Camera status after opening settings: $cameraStatus');
        
        if (!cameraStatus.isGranted) {
          debugPrint('❌ Camera permission still not granted after opening settings');
          return false;
        }
        debugPrint('✅ Camera permission granted after opening settings');
      } else {
        // إذا لم تكن ممنوحة وليست مرفوضة بشكل دائم، طلب الصلاحيات
        debugPrint('📱 Requesting camera permission...');
        cameraStatus = await Permission.camera.request();
        debugPrint('Camera status after request: $cameraStatus');
        
        if (!cameraStatus.isGranted) {
          debugPrint('❌ Camera permission denied after request: $cameraStatus');
          return false;
        }
        debugPrint('✅ Camera permission granted after request');
      }

      // طلب صلاحيات الميكروفون إذا كان مفعلاً
      if (_config.enableAudio) {
        var microphoneStatus = await Permission.microphone.status;
        if (!microphoneStatus.isGranted) {
          microphoneStatus = await Permission.microphone.request();
          if (!microphoneStatus.isGranted) {
            debugPrint('Microphone permission denied, continuing without audio');
            _config = _config.copyWith(enableAudio: false);
          }
        }
      }

      // محاولة الحصول على الكاميرات مع معالجة أفضل للأخطاء
      debugPrint('📷 Getting available cameras...');
      List<CameraDescription> cameras = [];
      
      // محاولات متعددة للحصول على الكاميرات (خاصة على iOS)
      int maxRetries = 3;
      int retryCount = 0;
      
      while (cameras.isEmpty && retryCount < maxRetries) {
        try {
          debugPrint('📷 Attempt ${retryCount + 1}/$maxRetries: Getting available cameras...');
          cameras = await availableCameras();
          debugPrint('✅ Found ${cameras.length} camera(s)');
          
          if (cameras.isEmpty && retryCount < maxRetries - 1) {
            debugPrint('⚠️ No cameras found, retrying after delay...');
            await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
          }
        } catch (e, stackTrace) {
          debugPrint('❌ Error getting available cameras (attempt ${retryCount + 1}): $e');
          debugPrint('Stack trace: $stackTrace');
          
          if (retryCount < maxRetries - 1) {
            debugPrint('🔄 Retrying after delay...');
            await Future.delayed(Duration(milliseconds: 1000 * (retryCount + 1)));
          } else {
            debugPrint('❌ All retry attempts failed');
            return false;
          }
        }
        retryCount++;
      }
      
      if (cameras.isEmpty) {
        debugPrint('❌ No cameras found on this device after $maxRetries attempts');
        debugPrint('❌ This could be due to:');
        debugPrint('   1. Camera permissions not properly granted');
        debugPrint('   2. Camera hardware not available');
        debugPrint('   3. iOS Simulator (cameras not supported)');
        debugPrint('   4. Camera plugin not properly registered');
        return false;
      }

      debugPrint('📷 Found ${cameras.length} camera(s):');
      for (int i = 0; i < cameras.length; i++) {
        debugPrint('   Camera $i: ${cameras[i].name} (${cameras[i].lensDirection})');
      }
      
      // ✅ إضافة تحقق إضافي للتشخيص
      if (cameras.isEmpty) {
        debugPrint('❌❌❌ CRITICAL: No cameras found on device!');
        debugPrint('   This is likely the root cause of camera not working.');
        debugPrint('   Possible reasons:');
        debugPrint('   1. Camera permissions not granted');
        debugPrint('   2. Device has no camera hardware');
        debugPrint('   3. Camera plugin not properly registered');
        debugPrint('   4. iOS Simulator (cameras not supported)');
        return false;
      }

      // اختيار الكاميرا المناسبة (الخلفية أولاً، ثم الأمامية)
      CameraDescription? selectedCamera;
      try {
        // محاولة العثور على الكاميرا الخلفية أولاً
        selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
      } catch (e) {
        selectedCamera = cameras.first;
      }
      
      debugPrint('📷 Selected camera: ${selectedCamera.name} (${selectedCamera.lensDirection})');

      // دقة متوسطة أولاً — أعلى توافقاً على أجهزة Android/iOS الحقيقية
      ResolutionPreset resolution = ResolutionPreset.medium;
      int initRetries = 3;
      bool initialized = false;

      // لا نمرّر imageFormatGroup على iOS/Android: فرض JPEG كان يسبب تعليق/فشل تهيئة على أجهزة حقيقية؛ الافتراضي من الـ plugin أنسب.
      
      for (int i = 0; i < initRetries && !initialized; i++) {
        try {
          debugPrint('📷 Initializing camera controller (attempt ${i + 1}/$initRetries)...');
          debugPrint('   Resolution: $resolution');
          
          // إلغاء تهيئة الكاميرا السابقة إذا كانت موجودة
          if (i > 0) {
            try {
              if (controller != null && controller!.value.isInitialized) {
                await controller!.dispose();
                debugPrint('   Disposed previous controller');
              }
            } catch (e) {
              debugPrint('   Error disposing previous controller: $e');
            }
            await Future.delayed(const Duration(milliseconds: 500));
          }
          
          controller = CameraController(
            selectedCamera,
            resolution,
            enableAudio: _config.enableAudio,
          );

          debugPrint('📷 Initializing camera hardware...');
          await controller!.initialize().timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Camera initialization timeout after 15 seconds');
            },
          );
          
          debugPrint('✅ Camera initialized successfully!');
          debugPrint('   Preview size: ${controller!.value.previewSize}');
          debugPrint('   Is initialized: ${controller!.value.isInitialized}');
          
          // ✅ التحقق النهائي من التهيئة
          if (controller!.value.isInitialized) {
            initialized = true;
            debugPrint('✅✅✅ Controller is fully initialized and ready!');
          } else {
            debugPrint('❌❌❌ Controller created but not initialized!');
            throw Exception('Controller initialization completed but isInitialized is false');
          }
        } catch (e, stackTrace) {
          debugPrint('❌ Camera initialization failed (attempt ${i + 1}): $e');
          debugPrint('Stack trace: $stackTrace');
          try {
            await controller?.dispose();
          } catch (_) {}
          controller = null;

          if (i < initRetries - 1) {
            // محاولة بدقة أقل (نبدأ من medium)
            if (resolution == ResolutionPreset.medium) {
              resolution = ResolutionPreset.low;
              debugPrint('🔄 Retrying with lower resolution: $resolution');
            } else if (resolution == ResolutionPreset.low) {
              debugPrint('🔄 Retrying again at low resolution (جهاز بطيء/تعارض)');
            } else if (resolution == ResolutionPreset.high) {
              resolution = ResolutionPreset.medium;
              debugPrint('🔄 Retrying with medium resolution: $resolution');
            }
            await Future.delayed(const Duration(milliseconds: 1000));
          } else {
            debugPrint('❌ All camera initialization attempts failed');
            return false;
          }
        }
      }
      
      if (!initialized) {
        debugPrint('❌ Failed to initialize camera after all attempts');
        return false;
      }
      
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Critical error initializing camera: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<CameraResult?> captureImage() async {
    if (controller == null || !controller!.value.isInitialized) {
      debugPrint('❌ Cannot capture: controller is ${controller == null ? "null" : "not initialized"}');
      throw CameraException('Camera not initialized', 'Please initialize camera first');
    }

    try {
      final XFile image = await controller!.takePicture();
      final String? audioPath = _config.enableAudio ? await _audioService.recordAudio() : null;

      final String mediaPath;
      if (_config.applyWatermark) {
        mediaPath = await _watermarkService.addWatermark(
          image.path,
          _config.watermarkText,
          _config.watermarkPosition,
          _config.watermarkOpacity,
          _config.watermarkColor,
          _config.watermarkSize,
        );
      } else {
        mediaPath = image.path;
      }

      // Get image dimensions
      final imageFile = await image.readAsBytes();
      ui.Image? decodedImage;
      try {
        decodedImage = await decodeImageFromList(imageFile);
      } catch (e) {
        debugPrint('Warning: Could not decode image for dimensions: $e');
        // استخدام أبعاد افتراضية
        decodedImage = null;
      }

      return CameraResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: mediaPath,
        type: MediaType.image,
        timestamp: DateTime.now(),
        metadata: await _createMetadata(),
        dimensions: decodedImage != null 
            ? Size(decodedImage.width.toDouble(), decodedImage.height.toDouble())
            : const Size(1920, 1080), // أبعاد افتراضية
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
      watermarkInfo: _config.applyWatermark
          ? '${_config.watermarkText} - ${_config.watermarkPosition}'
          : '',
      hasAudio: _config.enableAudio,
      createdBy: 'Test User',
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> _getCameraSettings() {
    if (controller == null) {
      return {
        'isInitialized': false,
        'error': 'Controller is null',
      };
    }
    return {
      'isInitialized': controller!.value.isInitialized,
      'previewSize': {
        'width': controller!.value.previewSize?.width,
        'height': controller!.value.previewSize?.height,
      },
      'flashMode': controller!.value.flashMode.toString(),
      'exposureMode': controller!.value.exposureMode.toString(),
      'focusMode': controller!.value.focusMode.toString(),
      'enableAudio': _config.enableAudio,
      'resolution': _config.resolution,
    };
  }

  void updateConfig(CameraConfig newConfig) {
    _config = newConfig;
    if (controller != null && controller!.value.isInitialized) {
      controller!.setFlashMode(FlashMode.auto);
      // Update other camera settings based on config
    }
  }

  Future<void> dispose() async {
    try {
      if (controller != null && controller!.value.isInitialized) {
        await controller!.dispose();
        debugPrint('✅ Camera controller disposed successfully');
      }
      controller = null; // ✅ Clear reference after disposal
    } catch (e) {
      debugPrint('Error disposing camera: $e');
    }
  }
} 