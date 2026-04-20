import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:like_button/like_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../properties/models/property_model.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../auth/providers/auth_state.dart';
import 'optimized_image.dart';

/// Widget لعرض عنصر عقار في القائمة
///
/// يعرض صورة العقار، العنوان، السعر، والعنوان
/// يدعم المفضلة والتفاعل مع المستخدم
/// يتبع الثيم الموحد للتطبيق
class PropertyListItem extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback onTap;
  final Function(String) onError;

  const PropertyListItem({
    super.key,
    required this.property,
    required this.onTap,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // صورة العقار
                OptimizedImage(
                  imageUrl: property.images.isNotEmpty ? property.images.first : null,
                  aspectRatio: 16 / 9,
                ),
                // زر المفضلة
                Positioned(
                  top: 8,
                  right: 8,
                  child: Consumer2<FavoritesProvider, AuthState>(
                    builder: (context, favoritesProvider, authState, _) {
                      final userId = authState.user?.id;
                      final isFavorite = userId != null && favoritesProvider.isFavorite(property.id);
                      return LikeButton(
                        isLiked: isFavorite,
                        circleColor: const CircleColor(
                          start: AppColors.error,
                          end: AppColors.primary,
                        ),
                        onTap: (isLiked) async {
                          if (userId == null) {
                            onError('يجب تسجيل الدخول أولاً');
                            return false;
                          }
                          if (isLiked) {
                            await favoritesProvider.removeFromFavorites(property.id, userId);
                          } else {
                            await favoritesProvider.addToFavorites(property, userId);
                          }
                          return !isLiked;
                        },
                      );
                    },
                  ),
                ),
                // مؤشر عدد الصور
                if (property.images.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_library,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${property.images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // معلومات العقار
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '﷼ ${property.price}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: AppColors.textPrimary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.address,
                          style: TextStyle(color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
