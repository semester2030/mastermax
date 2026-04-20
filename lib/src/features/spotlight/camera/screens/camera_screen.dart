import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_brand.dart';
import '../services/camera_service.dart';
import '../services/panorama_service.dart';
import '../services/three_d_service.dart';
import '../services/watermark_service.dart';
import '../services/audio_service.dart';
import '../services/camera_storage_service.dart';
import '../models/camera_config.dart';
import '../../../settings/providers/app_user_settings_provider.dart';
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
  CameraService? _cameraService;
  PanoramaService? _panoramaService;
  ThreeDService? _threeDService;
  final CameraStorageService _storageService = CameraStorageService();
  CameraMode _currentMode = CameraMode.normal;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isInitializing = false; // لمنع التهيئة المتعددة
  /// إن بقيت الشاشة على «جاري التهيئة» بدون رسالة، كان السبب غالباً عدم استدعاء setState بعد رفض الصلاحية أو فشل التهيئة.
  String? _blockingError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // طلب صلاحيات الكاميرا فوراً عند فتح الشاشة
    _requestCameraPermissionFirst();
  }

  /// طلب صلاحيات الكاميرا أولاً (قبل التهيئة)
  Future<void> _requestCameraPermissionFirst() async {
    try {
      debugPrint('📱 Requesting camera permission BEFORE initialization...');
      
      // التحقق من حالة الصلاحيات
      var cameraStatus = await Permission.camera.status;
      debugPrint('Initial camera permission status: $cameraStatus');
      
      // إذا لم تكن ممنوحة، طلبها فوراً
      if (!cameraStatus.isGranted) {
        if (cameraStatus.isPermanentlyDenied) {
          // إذا كانت مرفوضة بشكل دائم، فتح الإعدادات
          debugPrint('⚠️ Camera permission permanently denied - opening settings');
          final opened = await openAppSettings();
          debugPrint('Settings opened: $opened');
          
          // انتظار ثم إعادة التحقق
          await Future.delayed(const Duration(seconds: 2));
          cameraStatus = await Permission.camera.status;
          
          if (!cameraStatus.isGranted && mounted) {
            setState(() {
              _blockingError =
                  'لم يُسمح بالكاميرا. افتح الإعدادات وفعّل الكاميرا لتطبيق ${AppBrand.displayName} ثم اضغط إعادة المحاولة.';
              _isInitializing = false;
            });
            _showErrorDialogWithActions(
              'صلاحيات الكاميرا مطلوبة',
              'يرجى السماح بالوصول إلى الكاميرا من إعدادات التطبيق.\n\nSettings > Privacy & Security > Camera > ${AppBrand.displayName}',
              [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                  child: const Text('فتح الإعدادات'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
              ],
            );
            return;
          }
        } else {
          // طلب الصلاحيات
          debugPrint('📱 Requesting camera permission...');
          cameraStatus = await Permission.camera.request();
          debugPrint('Camera status after request: $cameraStatus');
          
          if (!cameraStatus.isGranted && mounted) {
            setState(() {
              _blockingError =
                  'تم رفض إذن الكاميرا. اضغط إعادة المحاولة واسمح بالوصول عند الطلب.';
              _isInitializing = false;
            });
            _showErrorDialogWithActions(
              'صلاحيات الكاميرا مطلوبة',
              'يرجى السماح بالوصول إلى الكاميرا لاستخدام هذه الميزة.',
              [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() => _blockingError = null);
                    _requestCameraPermissionFirst(); // إعادة المحاولة
                  },
                  child: const Text('إعادة المحاولة'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
              ],
            );
            return;
          }
        }
      }
      
      debugPrint('✅ Camera permission granted - proceeding with initialization');
      
      // بعد منح الصلاحيات، تهيئة الكاميرا
      if (mounted) {
        setState(() {
          _blockingError = null;
        });
        await _initializeServices();
      }
    } catch (e) {
      debugPrint('Error requesting camera permission: $e');
      if (mounted) {
        setState(() {
          _blockingError = 'خطأ أثناء طلب صلاحية الكاميرا: $e';
          _isInitializing = false;
        });
        _showErrorDialog(
          'خطأ في طلب صلاحيات الكاميرا',
          'حدث خطأ أثناء طلب صلاحيات الكاميرا. يرجى المحاولة مرة أخرى.',
        );
      }
    }
  }

  Future<void> _initializeServices() async {
    // منع التهيئة المتعددة
    if (_isInitializing) {
      debugPrint('⚠️ Camera initialization already in progress, skipping...');
      return;
    }
    
    _isInitializing = true;
    
    try {
      // تنظيف الخدمات القديمة إذا كانت موجودة
      if (_cameraService != null) {
        debugPrint('🧹 Disposing old camera service...');
        try {
          _cameraService!.dispose();
        } catch (e) {
          debugPrint('Error disposing old camera: $e');
        }
      }
      
      final watermarkService = WatermarkService();
      final audioService = AudioService();

      final userSettings = context.read<AppUserSettingsProvider>();
      await userSettings.ensureLoaded();
      if (!mounted) return;

      final baseConfig = widget.initialConfig ?? const CameraConfig();
      final resolvedConfig = baseConfig.copyWith(
        applyWatermark: userSettings.enableWatermarkVideos,
      );

      _cameraService = CameraService(
        watermarkService: watermarkService,
        audioService: audioService,
        config: resolvedConfig,
      );
      _panoramaService = PanoramaService();
      _threeDService = ThreeDService();

      // إضافة timeout للتهيئة (30 ثانية - زيادة الوقت)
      final initialized = await _cameraService!.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('❌ Camera initialization timeout after 30 seconds');
          debugPrint('❌ This might indicate:');
          debugPrint('   1. Camera hardware issue');
          debugPrint('   2. Permission issue (even if granted)');
          debugPrint('   3. iOS camera plugin registration issue');
          return false;
        },
      );
      
      if (mounted) {
        if (initialized) {
          setState(() {
            _isInitialized = true;
            _isInitializing = false;
            _blockingError = null;
          });
        } else {
          _isInitializing = false;
          // التحقق من سبب الفشل
          final cameraStatus = await Permission.camera.status;
          debugPrint('Camera initialization failed. Status: $cameraStatus');

          String failHint;
          if (cameraStatus.isPermanentlyDenied) {
            failHint =
                'الكاميرا مرفوضة من الإعدادات. فعّلها لـ ${AppBrand.displayName} ثم أعد المحاولة.';
          } else if (!cameraStatus.isGranted) {
            failHint = 'لم يُمنح إذن الكاميرا.';
          } else {
            failHint =
                'تعذر تشغيل الكاميرا على هذا الجهاز (لا توجد كاميرا أو تعارض مع تطبيق آخر).';
          }
          if (mounted) {
            setState(() => _blockingError = failHint);
          }
          
          if (cameraStatus.isPermanentlyDenied) {
            _showErrorDialogWithActions(
              'صلاحيات الكاميرا مرفوضة',
              'يرجى السماح بالوصول إلى الكاميرا من إعدادات التطبيق.\n\nSettings > Privacy & Security > Camera > ${AppBrand.displayName}',
              [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                  child: const Text('فتح الإعدادات'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
              ],
            );
          } else if (!cameraStatus.isGranted) {
            _showErrorDialogWithActions(
              'صلاحيات الكاميرا مرفوضة',
              'يرجى السماح بالوصول إلى الكاميرا عند الطلب.',
              [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() => _blockingError = null);
                    _initializeServices(); // إعادة المحاولة
                  },
                  child: const Text('إعادة المحاولة'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
              ],
            );
          } else {
            _showErrorDialogWithActions(
              'لا توجد كاميرا متاحة',
              'لم يتم العثور على كاميرا في هذا الجهاز. يرجى التحقق من أن الجهاز يحتوي على كاميرا وأنها تعمل بشكل صحيح.',
              [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('حسناً'),
                ),
              ],
            );
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing camera: $e');
      debugPrint('Stack trace: $stackTrace');
      _isInitializing = false;
      if (mounted) {
        setState(() {
          _blockingError =
              'فشل تهيئة الكاميرا. أغلق تطبيقات أخرى تستخدم الكاميرا ثم أعد المحاولة.\n($e)';
        });
        _showErrorDialogWithActions(
          'فشل في تهيئة الكاميرا',
          'حدث خطأ أثناء تهيئة الكاميرا. يرجى المحاولة مرة أخرى أو استخدام جهاز آخر.',
          [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _blockingError = null);
                _initializeServices(); // إعادة المحاولة
              },
              child: const Text('إعادة المحاولة'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
          ],
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final svc = _cameraService;
    if (svc != null) {
      unawaited(svc.dispose());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // بعد العودة من الإعدادات (كان هناك خطأ معروض) نعيد التهيئة فقط لتفادي استدعاء مزدوج عند أول فتح
    if (state == AppLifecycleState.resumed &&
        mounted &&
        !_isInitialized &&
        !_isInitializing &&
        _blockingError != null) {
      Permission.camera.status.then((status) {
        if (!mounted || !status.isGranted) return;
        debugPrint('App resumed — إعادة محاولة تهيئة الكاميرا بعد تصحيح الإعدادات');
        setState(() => _blockingError = null);
        _initializeServices();
      });
      return;
    }

    if (!_isInitialized || _cameraService == null) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      debugPrint('App went to background, keeping camera active');
    }
  }

  Future<void> _captureImage() async {
    if (_isProcessing || _cameraService == null || !_isInitialized) return;

    setState(() => _isProcessing = true);
    try {
      switch (_currentMode) {
        case CameraMode.normal:
          final result = await _cameraService!.captureImage();
          if (result != null && mounted) {
            // رفع الصورة إلى Firebase Storage
            try {
              setState(() => _isProcessing = true);
              final imageFile = File(result.path);
              final downloadUrl = await _storageService.uploadImage(imageFile);
              
              if (mounted) {
                _showSuccessMessage('تم التقاط الصورة ورفعها بنجاح');
                debugPrint('Image uploaded to: $downloadUrl');
                // يمكنك حفظ downloadUrl في Firestore أو استخدامها حسب الحاجة
              }
            } catch (e) {
              debugPrint('Error uploading image: $e');
              if (mounted) {
                _showErrorDialog(
                  'فشل في رفع الصورة',
                  'تم التقاط الصورة لكن فشل رفعها إلى السحابة. الصورة محفوظة محلياً.',
                );
              }
            } finally {
              if (mounted) {
                setState(() => _isProcessing = false);
              }
            }
          }
          break;

        case CameraMode.panorama:
          if (_panoramaService == null) break;
          if (!_panoramaService!.isCapturing) {
            await _panoramaService!.startCapture();
          }
          final currentImage = await _cameraService!.captureImage();
          if (currentImage?.path != null) {
            await _panoramaService!.addImage(currentImage!.path);
          }
          
          if (_panoramaService!.capturedCount >= _panoramaService!.requiredImages) {
            final result = await _panoramaService!.finishCapture();
            if (result != null && mounted) {
              // رفع الصورة البانورامية إلى Firebase Storage
              try {
                setState(() => _isProcessing = true);
                final imageFile = File(result.path);
                final downloadUrl = await _storageService.uploadPanoramaImage(imageFile);
                
                if (mounted) {
                  _showSuccessMessage('تم إنشاء الصورة البانورامية ورفعها بنجاح');
                  debugPrint('Panorama uploaded to: $downloadUrl');
                }
              } catch (e) {
                debugPrint('Error uploading panorama: $e');
                if (mounted) {
                  _showErrorDialog(
                    'فشل في رفع الصورة البانورامية',
                    'تم إنشاء الصورة لكن فشل رفعها إلى السحابة.',
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isProcessing = false);
                }
              }
            }
          }
          break;

        case CameraMode.threeD:
          if (_threeDService == null) break;
          if (!_threeDService!.isCapturing) {
            await _threeDService!.startCapture();
          }
          final currentImage = await _cameraService!.captureImage();
          if (currentImage?.path != null) {
            await _threeDService!.addImage(currentImage!.path);
          }
          
          if (_threeDService!.capturedCount >= _threeDService!.requiredAngles) {
            final result = await _threeDService!.finishCapture();
            if (result != null && mounted) {
              // رفع النموذج 3D إلى Firebase Storage
              try {
                setState(() => _isProcessing = true);
                // النموذج 3D هو مجلد، نحتاج رفع جميع الصور فيه
                final modelDir = Directory(result.path);
                if (await modelDir.exists()) {
                  final files = modelDir.listSync()
                      .whereType<File>()
                      .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
                      .toList();
                  
                  final List<String> uploadedUrls = [];
                  for (final file in files) {
                    final url = await _storageService.upload3DImage(file);
                    uploadedUrls.add(url);
                  }
                  
                  if (mounted) {
                    _showSuccessMessage('تم إنشاء النموذج ثلاثي الأبعاد ورفعه بنجاح');
                    debugPrint('3D model uploaded: ${uploadedUrls.length} images');
                  }
                }
              } catch (e) {
                debugPrint('Error uploading 3D model: $e');
                if (mounted) {
                  _showErrorDialog(
                    'فشل في رفع النموذج ثلاثي الأبعاد',
                    'تم إنشاء النموذج لكن فشل رفعه إلى السحابة.',
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isProcessing = false);
                }
              }
            }
          }
          break;
      }
    } catch (e, stackTrace) {
      debugPrint('Error capturing image: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        _showErrorDialog('حدث خطأ أثناء التقاط الصورة', 'يرجى المحاولة مرة أخرى');
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
        if (mode != CameraMode.panorama && _panoramaService != null) {
          _panoramaService!.cancelCapture();
        }
        if (mode != CameraMode.threeD && _threeDService != null) {
          _threeDService!.cancelCapture();
        }
      });
    }
  }

  void _showErrorDialog(String title, [String? message, VoidCallback? onOk]) {
    showDialog(
      context: context,
      barrierDismissible: true, // يمكن إغلاقه بالنقر خارج الصندوق
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onOk != null) {
                onOk();
              }
            },
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialogWithActions(String title, String message, List<Widget> actions) {
    showDialog(
      context: context,
      barrierDismissible: true, // يمكن إغلاقه بالنقر خارج الصندوق
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: actions,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('الكاميرا'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_blockingError != null) ...[
                  Icon(Icons.videocam_off_outlined,
                      size: 56, color: AppColors.error.withValues(alpha: 0.85)),
                  const SizedBox(height: 16),
                  Text(
                    _blockingError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isInitializing
                        ? null
                        : () {
                            setState(() => _blockingError = null);
                            _requestCameraPermissionFirst();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('إعادة المحاولة'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('رجوع'),
                  ),
                ] else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text(
                    'جاري تهيئة الكاميرا...',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // ✅ التحقق المزدوج: _cameraService موجود + controller موجود + controller مهيأ
    final isCameraReady = _cameraService != null &&
        _cameraService!.controller != null &&
        _cameraService!.controller!.value.isInitialized;

    debugPrint('🔍 Camera Screen Build Check:');
    debugPrint('   _isInitialized: $_isInitialized');
    debugPrint('   _cameraService != null: ${_cameraService != null}');
    debugPrint('   controller != null: ${_cameraService?.controller != null}');
    debugPrint('   controller.isInitialized: ${_cameraService?.controller?.value.isInitialized ?? false}');
    debugPrint('   isCameraReady: $isCameraReady');

    if (!isCameraReady) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('الكاميرا'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                'جاري تهيئة الكاميرا...',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Controller: ${_cameraService?.controller != null ? "موجود" : "غير موجود"}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'Initialized: ${_cameraService?.controller?.value.isInitialized ?? false}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview - ✅ الآن آمن 100%
          Positioned.fill(
            child: Center(
              child: AspectRatio(
                aspectRatio:
                    _cameraService!.controller!.value.aspectRatio,
                child: CameraPreview(_cameraService!.controller!),
              ),
            ),
          ),

          // Overlay
          CameraOverlay(
            mode: _currentMode,
            panoramaProgress: _panoramaService?.progress ?? 0.0,
            threeDProgress: _threeDService?.progress ?? 0.0,
            threeDAngle: _threeDService?.currentAngle ?? 0.0,
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