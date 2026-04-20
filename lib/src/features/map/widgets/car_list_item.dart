import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:like_button/like_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../cars/models/car_model.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../auth/providers/auth_state.dart';
import 'optimized_image.dart';

/// Widget لعرض عنصر سيارة في القائمة
///
/// يعرض صورة السيارة، العنوان، السعر، والعنوان
/// يدعم المفضلة والتفاعل مع المستخدم
/// يتبع الثيم الموحد للتطبيق
class CarListItem extends StatelessWidget {
  final CarModel car;
  final VoidCallback onTap;
  final Function(String) onError;

  const CarListItem({
    super.key,
    required this.car,
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
                // صورة السيارة
                OptimizedImage(
                  imageUrl: car.images.isNotEmpty ? car.images.first : null,
                  aspectRatio: 16 / 9,
                ),
                // زر المفضلة
                Positioned(
                  top: 8,
                  right: 8,
                  child: Consumer2<FavoritesProvider, AuthState>(
                    builder: (context, favoritesProvider, authState, _) {
                      final userId = authState.user?.id;
                      final isFavorite = userId != null && favoritesProvider.isFavorite(car.id);
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
                            await favoritesProvider.removeFromFavorites(car.id, userId);
                          } else {
                            await favoritesProvider.addToFavorites(car, userId);
                          }
                          return !isLiked;
                        },
                      );
                    },
                  ),
                ),
                // مؤشر عدد الصور
                if (car.images.length > 1)
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
                            '${car.images.length}',
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
            // معلومات السيارة
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '﷼ ${car.price}',
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
                          car.address,
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
