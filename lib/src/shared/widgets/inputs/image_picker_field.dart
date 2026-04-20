import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerField extends StatelessWidget {
  final List<String> images;
  final Function(List<String>) onImagesChanged;
  final Function(String) onImageSelected;
  final String? errorText;
  final bool enabled;
  final int maxImages;
  final String? label;

  const ImagePickerField({
    required this.images, required this.onImagesChanged, required this.onImageSelected, super.key,
    this.errorText,
    this.enabled = true,
    this.maxImages = 10,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (images.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      for (var image in images)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: image.startsWith('http')
                                    ? Image.network(
                                        image,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 80,
                                            height: 80,
                                            color: AppColors.surface,
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: AppColors.textSecondary,
                                            ),
                                          );
                                        },
                                      )
                                    : Image.file(
                                        File(image),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 80,
                                            height: 80,
                                            color: AppColors.surface,
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: AppColors.textSecondary,
                                            ),
                                          );
                                        },
                                      ),
                              ),
                              if (enabled)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      final newImages = List<String>.from(images);
                                      newImages.remove(image);
                                      onImagesChanged(newImages);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(),
              ],
              if (enabled && images.length < maxImages)
                InkWell(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final int remaining = maxImages - images.length;
                    if (remaining <= 0) {
                      return;
                    }

                    // ✅ السماح باختيار عدة صور مرة واحدة
                    final List<XFile> pickedImages = await picker.pickMultiImage(
                      imageQuality: 95, // ✅ جودة عالية
                    );

                    if (pickedImages.isNotEmpty) {
                      // نضيف فقط حتى نصل إلى الحد الأقصى
                      for (final image in pickedImages.take(remaining)) {
                        onImageSelected(image.path);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: images.isEmpty
                          ? BorderRadius.circular(8)
                          : const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'إضافة صورة',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
} 