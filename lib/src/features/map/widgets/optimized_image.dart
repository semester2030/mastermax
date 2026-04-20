import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import 'shimmer_placeholder.dart';

/// Widget لعرض صورة محسّنة مع دعم التخزين المؤقت
///
/// يستخدم CachedNetworkImage لتحسين الأداء
/// يتبع الثيم الموحد للتطبيق
class OptimizedImage extends StatelessWidget {
  final String? imageUrl;
  final double aspectRatio;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          color: AppColors.background,
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              size: 48,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => ShimmerPlaceholder(
          child: Container(color: AppColors.white),
        ),
        errorWidget: (context, url, error) {
          debugPrint('❌ Error loading image: $url - $error');
          return Container(
            color: AppColors.background,
            child: const Center(
              child: Icon(
                Icons.error_outline,
                size: 32,
                color: AppColors.error,
              ),
            ),
          );
        },
        // ✅ تحسين الأداء - تقليل حجم الصور المحفوظة في الذاكرة
        maxWidthDiskCache: 800,
        maxHeightDiskCache: 600,
      ),
    );
  }
}
