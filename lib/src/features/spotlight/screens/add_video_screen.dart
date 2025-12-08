import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide ImageSource;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/video_provider.dart';
import '../models/spotlight_category.dart';
import '../../../core/widgets/loading_overlay.dart';
import 'package:mastermax_2030/src/core/theme/app_colors.dart';

class AddVideoScreen extends StatefulWidget {
  final SpotlightCategory category;

  const AddVideoScreen({
    required this.category, super.key,
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
  Point? _selectedLocation;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _videoController?.dispose();
    super.dispose();
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
        setState(() {
          _videoPath = video.path;
        });

        _videoController = VideoPlayerController.file(File(_videoPath!))
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() {});
          });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في اختيار الفيديو: $e')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_videoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار فيديو')),
        );
        return;
      }

      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء تحديد الموقع')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final videoProvider = context.read<VideoProvider>();
        // تحويل Point إلى GeoPoint
        final geoPoint = GeoPoint(
          _selectedLocation!.coordinates.lat.toDouble(),
          _selectedLocation!.coordinates.lng.toDouble()
        );
        
        await videoProvider.uploadVideo(
          title: _titleController.text,
          description: _descriptionController.text,
          price: double.parse(_priceController.text),
          videoPath: _videoPath!,
          thumbnailPath: _thumbnailPath,
          location: geoPoint,
          address: _addressController.text,
          category: widget.category,
        );

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع الفيديو بنجاح')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في رفع الفيديو: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة فيديو جديد'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitForm,
            child: const Text('نشر'),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
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
                    labelText: 'عنوان الفيديو',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال عنوان الفيديو';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'وصف الفيديو',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال وصف الفيديو';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'السعر',
                    border: OutlineInputBorder(),
                    prefixText: 'ريال ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال السعر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MapWidget(
                    key: const ValueKey('addVideoMap'),
                    styleUri: MapboxStyles.MAPBOX_STREETS,
                    cameraOptions: CameraOptions(
                      center: Point(
                        coordinates: Position(46.6753, 24.7136), // الرياض
                      ),
                      zoom: 15.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال العنوان';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (_videoPath == null) {
      return InkWell(
        onTap: _pickVideo,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library, size: 48),
                SizedBox(height: 8),
                Text('اضغط لاختيار فيديو'),
              ],
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_videoController!),
          IconButton(
            icon: Icon(
              _videoController!.value.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
              size: 48,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _videoController!.value.isPlaying
                    ? _videoController!.pause()
                    : _videoController!.play();
              });
            },
          ),
        ],
      ),
    );
  }
} 