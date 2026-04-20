import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/video_provider.dart';
import '../services/video_service.dart';
import '../models/spotlight_category.dart';
import '../models/video_model.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../shared/widgets/inputs/location_picker_field.dart';
import '../../properties/services/property_location_service.dart';
import 'package:mastermax_2030/src/core/theme/app_colors.dart';

class AddVideoScreen extends StatefulWidget {
  final SpotlightCategory category;
  final VideoModel? editVideo; // للتحرير

  const AddVideoScreen({
    required this.category,
    this.editVideo,
    super.key,
  });

  @override
  State<AddVideoScreen> createState() => _AddVideoScreenState();
}

class _AddVideoScreenState extends State<AddVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  VideoPlayerController? _videoController;
  String? _videoPath;
  String? _thumbnailPath;
  LatLng? _selectedLocation;
  GeoPoint? _selectedGeoPoint;
  String _selectedAddress = '';
  bool _isLoading = false;
  /// مرحلة النشر + نسبة رفع الملف (0…1) لعرض [LoadingOverlay].
  String? _uploadPhaseMessage;
  double? _uploadFileFraction;
  final _propertyLocationService = PropertyLocationService();

  @override
  void initState() {
    super.initState();
    
    // إذا كان في وضع التعديل، تحميل بيانات الفيديو
    if (widget.editVideo != null) {
      final video = widget.editVideo!;
      _titleController.text = video.title;
      _descriptionController.text = video.description;
      if (video.price != null) {
        _priceController.text = video.price.toString();
      }
      _addressController.text = video.address;
      _selectedLocation = LatLng(video.location.latitude, video.location.longitude);
      _selectedGeoPoint = video.location;
      _selectedAddress = video.address;
      _videoPath = video.url; // URL الفيديو
      _thumbnailPath = video.thumbnail; // URL الصورة المصغرة
      
      // ✅ تهيئة VideoPlayerController للفيديو الموجود (URL)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeVideoController();
      });
    } else {
      // الحصول على الموقع الحالي تلقائياً
      _getCurrentLocation();
    }
  }
  
  /// تهيئة VideoPlayerController (يدعم URL ومسار ملف محلي)
  Future<void> _initializeVideoController() async {
    if (_videoPath == null) return;
    
    try {
      // التحقق إذا كان URL أم مسار ملف محلي
      final isUrl = _videoPath!.startsWith('http://') || _videoPath!.startsWith('https://');
      
      if (isUrl) {
        // استخدام VideoPlayerController.networkUrl للـ URLs
        _videoController = VideoPlayerController.networkUrl(Uri.parse(_videoPath!));
      } else {
        // استخدام VideoPlayerController.file للملفات المحلية
        _videoController = VideoPlayerController.file(File(_videoPath!));
      }
      
      await _videoController!.initialize();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Error initializing video controller: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحميل الفيديو: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await _propertyLocationService.getCurrentLocation();
      final address = await _propertyLocationService.getAddressFromLocation(location);
      
      if (mounted) {
        setState(() {
          _selectedLocation = location;
          _selectedGeoPoint = GeoPoint(location.latitude, location.longitude);
          _selectedAddress = address;
          _addressController.text = address;
        });
      }
    } catch (e) {
      debugPrint('فشل في الحصول على الموقع الحالي: $e');
      // استخدام الموقع الافتراضي (الرياض)
      if (mounted) {
        setState(() {
          _selectedLocation = const LatLng(24.7136, 46.6753);
          _selectedGeoPoint = const GeoPoint(24.7136, 46.6753);
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (!mounted) return;

      if (video != null) {
        // ✅ إغلاق الـ controller القديم أولاً
        await _videoController?.dispose();
        
        setState(() {
          _videoPath = video.path;
        });

        // ✅ تهيئة الـ controller للملف الجديد
        _videoController = VideoPlayerController.file(File(_videoPath!));
        
        try {
          await _videoController!.initialize();
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          debugPrint('❌ Error initializing picked video: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل في تحميل الفيديو المختار: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في اختيار الفيديو: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      // ✅ عند التعديل، لا نحتاج فيديو جديد (الفيديو موجود بالفعل)
      if (widget.editVideo == null && _videoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء اختيار فيديو'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedGeoPoint == null || _selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء تحديد الموقع'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      // ✅ عند التعديل، يجب أن يكون _videoPath موجود (URL الفيديو الأصلي)
      if (widget.editVideo != null && _videoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: لم يتم العثور على الفيديو'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _uploadPhaseMessage = null;
        _uploadFileFraction = null;
      });

      try {
        final videoProvider = context.read<VideoProvider>();
        
        if (widget.editVideo != null) {
          // تحديث الفيديو
          await videoProvider.updateVideo(
            videoId: widget.editVideo!.id,
            // العنوان والوصف أصبحا اختياريين، نستخدم قيم افتراضية عند الفراغ
            title: _titleController.text.isNotEmpty ? _titleController.text : 'بدون عنوان',
            description: _descriptionController.text.isNotEmpty ? _descriptionController.text : 'بدون وصف',
            price: _priceController.text.isNotEmpty 
                ? double.tryParse(_priceController.text) 
                : null,
            location: _selectedGeoPoint!,
            address: _selectedAddress.isNotEmpty ? _selectedAddress : _addressController.text,
          );

          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث الفيديو بنجاح')),
          );
        } else {
          // رفع فيديو جديد
          // ✅ التحقق من أن _videoPath هو مسار ملف محلي (ليس URL)
          final isUrl = _videoPath!.startsWith('http://') || _videoPath!.startsWith('https://');
          if (isUrl) {
            throw Exception('لا يمكن رفع فيديو من رابط. يرجى اختيار فيديو من الجهاز.');
          }
          
          setState(() {
            _uploadPhaseMessage = VideoService.uploadUiPrepare;
            _uploadFileFraction = null;
          });

          await videoProvider.uploadVideo(
            // العنوان والوصف أصبحا اختياريين، نستخدم قيم افتراضية عند الفراغ
            title: _titleController.text.isNotEmpty ? _titleController.text : 'بدون عنوان',
            description: _descriptionController.text.isNotEmpty ? _descriptionController.text : 'بدون وصف',
            price: _priceController.text.isNotEmpty 
                ? double.tryParse(_priceController.text) 
                : null,
            videoPath: _videoPath!,
            thumbnailPath: _thumbnailPath,
            location: _selectedGeoPoint!,
            address: _selectedAddress.isNotEmpty ? _selectedAddress : _addressController.text,
            category: widget.category,
            onUploadUi: (phase, fraction) {
              if (!mounted) return;
              setState(() {
                _uploadPhaseMessage = phase;
                _uploadFileFraction = fraction;
              });
            },
          );

          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفع الفيديو بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Error in _submitForm: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.editVideo != null 
                  ? 'فشل في تحديث الفيديو: $e'
                  : 'فشل في رفع الفيديو: $e'
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _uploadPhaseMessage = null;
            _uploadFileFraction = null;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editVideo != null ? 'تعديل الفيديو' : 'إضافة فيديو جديد'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // ✅ إغلاق الـ controller قبل الرجوع
            _videoController?.dispose();
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitForm,
            child: Text(widget.editVideo != null ? 'حفظ' : 'نشر'),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: _uploadPhaseMessage,
        progress: _uploadFileFraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildVideoPreview(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الفيديو (اختياري)',
                    border: OutlineInputBorder(),
                    helperText: 'يمكنك النشر بدون عنوان، سنضع \"بدون عنوان\" تلقائياً',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'وصف الفيديو (اختياري)',
                    border: OutlineInputBorder(),
                    helperText: 'يمكنك النشر بدون وصف، سنضع \"بدون وصف\" تلقائياً',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'السعر (اختياري)',
                    border: OutlineInputBorder(),
                    prefixText: 'ريال ',
                    helperText: 'يمكنك ترك السعر فارغاً',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 16),
                LocationPickerField(
                  label: 'الموقع',
                  initialAddress: _selectedAddress,
                  initialLocation: _selectedGeoPoint ?? const GeoPoint(24.7136, 46.6753),
                  onLocationSelected: (location, address) {
                    setState(() {
                      _selectedGeoPoint = location;
                      _selectedLocation = LatLng(location.latitude, location.longitude);
                      _selectedAddress = address;
                      _addressController.text = address;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان التفصيلي (اختياري)',
                    border: OutlineInputBorder(),
                    helperText: 'يمكنك إضافة تفاصيل إضافية للعنوان',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    // ✅ عند التعديل، لا نسمح باختيار فيديو جديد (نعرض الفيديو الحالي فقط)
    final bool isEditMode = widget.editVideo != null;
    
    if (_videoPath == null) {
      return InkWell(
        onTap: isEditMode ? null : _pickVideo, // ✅ تعطيل عند التعديل
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library, 
                  size: 48,
                  color: isEditMode ? AppColors.textSecondary : AppColors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  isEditMode ? 'لا يمكن تغيير الفيديو عند التعديل' : 'اضغط لاختيار فيديو',
                  style: TextStyle(
                    color: isEditMode ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ التحقق من أن الـ controller جاهز
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحميل المقطع...'),
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_videoController!),
          // ✅ زر التشغيل/الإيقاف
          if (!_videoController!.value.isPlaying)
            IconButton(
              icon: const Icon(
                Icons.play_arrow,
                size: 48,
                color: AppColors.white,
              ),
              onPressed: () {
                _videoController!.play();
                setState(() {});
              },
            ),
          // ✅ زر الإيقاف عند التشغيل
          if (_videoController!.value.isPlaying)
            GestureDetector(
              onTap: () {
                _videoController!.pause();
                setState(() {});
              },
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          // ✅ معلومات الفيديو
          if (isEditMode)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'وضع التعديل',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 