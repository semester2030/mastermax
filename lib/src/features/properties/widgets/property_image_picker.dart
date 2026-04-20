import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

/// Widget لاختيار وعرض صور العقار
///
/// يدعم اختيار عدة صور وعرضها في PageView
/// يتبع الثيم الموحد للتطبيق
class PropertyImagePicker extends StatefulWidget {
  final List<String> images;
  final List<File> imageFiles;
  final ValueChanged<List<String>> onImagesChanged;
  final ValueChanged<List<File>> onImageFilesChanged;
  final ImagePicker imagePicker;

  const PropertyImagePicker({
    super.key,
    required this.images,
    required this.imageFiles,
    required this.onImagesChanged,
    required this.onImageFilesChanged,
    required this.imagePicker,
  });

  @override
  State<PropertyImagePicker> createState() => _PropertyImagePickerState();
}

class _PropertyImagePickerState extends State<PropertyImagePicker> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final int remaining = AppConstants.maxImagesPerProperty - widget.images.length;
      if (remaining <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن إضافة المزيد من الصور (تم الوصول للحد الأقصى)'),
          ),
        );
        return;
      }

      final List<XFile> pickedImages = await widget.imagePicker.pickMultiImage(
        imageQuality: 95,
      );

      if (!mounted) return;

      if (pickedImages.isNotEmpty) {
        final newImageFiles = <File>[];
        final newImages = <String>[];
        
        for (final image in pickedImages.take(remaining)) {
          newImageFiles.add(File(image.path));
          newImages.add(image.path);
        }

        widget.onImageFilesChanged([...widget.imageFiles, ...newImageFiles]);
        widget.onImagesChanged([...widget.images, ...newImages]);
        
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في اختيار الصورة: $e')),
      );
    }
  }

  void _deleteImage(int index) {
    final newImages = List<String>.from(widget.images);
    final newImageFiles = List<File>.from(widget.imageFiles);
    
    newImages.removeAt(index);
    if (index < newImageFiles.length) {
      newImageFiles.removeAt(index);
    }
    
    if (_currentImageIndex >= newImages.length) {
      _currentImageIndex = newImages.length - 1;
    }
    
    widget.onImagesChanged(newImages);
    widget.onImageFilesChanged(newImageFiles);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'صور العقار',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(AppColors.white, 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryLight),
          ),
          child: widget.images.isEmpty
              ? InkWell(
                  onTap: _pickImage,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppColors.textPrimary,
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'اضغط لإضافة صور',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: widget.images.length + 1,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        if (index == widget.images.length) {
                          return InkWell(
                            onTap: _pickImage,
                            child: Container(
                              decoration: BoxDecoration(
                                color: ColorUtils.withOpacity(AppColors.primary, 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: AppColors.textPrimary,
                                    size: 48,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'إضافة المزيد',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: widget.images[index].startsWith('http')
                                  ? Image.network(
                                      widget.images[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: AppColors.white,
                                          child: const Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: AppColors.textSecondary,
                                          ),
                                        );
                                      },
                                    )
                                  : Image.file(
                                      File(widget.images[index]),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: AppColors.white,
                                          child: const Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: AppColors.textSecondary,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.textSecondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.white,
                                    size: 20,
                                  ),
                                ),
                                onPressed: () => _deleteImage(index),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (widget.images.length > 1)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            widget.images.length + 1,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentImageIndex == index
                                    ? AppColors.primary
                                    : ColorUtils.withOpacity(AppColors.textSecondary, 0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
