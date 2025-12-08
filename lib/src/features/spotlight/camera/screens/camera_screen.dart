import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../../core/constants/route_constants.dart';
import '../services/camera_service.dart';
import '../services/panorama_service.dart';
import '../services/three_d_service.dart';
import '../services/watermark_service.dart';
import '../services/audio_service.dart';
import '../models/camera_config.dart';
import '../widgets/camera_controls.dart';
import '../widgets/camera_overlay.dart';
import '../widgets/mode_selector.dart';

class CameraScreen extends StatefulWidget {
  static String routeName = Routes.camera;
  
  final CameraConfig? initialConfig;
  
  const CameraScreen({super.key, this.initialConfig});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  late final CameraService _cameraService;
  late final PanoramaService _panoramaService;
  late final ThreeDService _threeDService;
  CameraMode _currentMode = CameraMode.normal;
  bool _isInitialized = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final watermarkService = WatermarkService();
      final audioService = AudioService();

      _cameraService = CameraService(
        watermarkService: watermarkService,
        audioService: audioService,
        config: widget.initialConfig,
      );
      _panoramaService = PanoramaService();
      _threeDService = ThreeDService();

      await _cameraService.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing camera: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        _showErrorDialog('فشل في تهيئة الكاميرا');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _cameraService.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeServices();
    }
  }

  Future<void> _captureImage() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      switch (_currentMode) {
        case CameraMode.normal:
          final result = await _cameraService.captureImage();
          if (result != null && mounted) {
            // Navigate to preview screen
            _showSuccessMessage('تم التقاط الصورة بنجاح');
          }
          break;

        case CameraMode.panorama:
          if (!_panoramaService.isCapturing) {
            await _panoramaService.startCapture();
          }
          final currentImage = await _cameraService.captureImage();
          if (currentImage?.path != null) {
            await _panoramaService.addImage(currentImage!.path);
          }
          
          if (_panoramaService.capturedCount >= _panoramaService.requiredImages) {
            final result = await _panoramaService.finishCapture();
            if (result != null && mounted) {
              _showSuccessMessage('تم إنشاء الصورة البانورامية بنجاح');
            }
          }
          break;

        case CameraMode.threeD:
          if (!_threeDService.isCapturing) {
            await _threeDService.startCapture();
          }
          final currentImage = await _cameraService.captureImage();
          if (currentImage?.path != null) {
            await _threeDService.addImage(currentImage!.path);
          }
          
          if (_threeDService.capturedCount >= _threeDService.requiredAngles) {
            final result = await _threeDService.finishCapture();
            if (result != null && mounted) {
              _showSuccessMessage('تم إنشاء النموذج ثلاثي الأبعاد بنجاح');
            }
          }
          break;
      }
    } catch (e, stackTrace) {
      debugPrint('Error capturing image: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        _showErrorDialog('حدث خطأ أثناء التقاط الصورة');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _switchMode(CameraMode mode) {
    if (_currentMode == mode) return;
    if (mounted) {
      setState(() {
        _currentMode = mode;
        // Reset services if needed
        if (mode != CameraMode.panorama) _panoramaService.cancelCapture();
        if (mode != CameraMode.threeD) _threeDService.cancelCapture();
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: 1,
              child: CameraPreview(_cameraService.controller),
            ),
          ),

          // Overlay
          CameraOverlay(
            mode: _currentMode,
            panoramaProgress: _panoramaService.progress,
            threeDProgress: _threeDService.progress,
            threeDAngle: _threeDService.currentAngle,
          ),

          // Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CameraControls(
              onCapture: _captureImage,
              isProcessing: _isProcessing,
            ),
          ),

          // Mode Selector
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: ModeSelector(
              currentMode: _currentMode,
              onModeSelected: _switchMode,
            ),
          ),
        ],
      ),
    );
  }
}

enum CameraMode {
  normal,
  panorama,
  threeD,
} 