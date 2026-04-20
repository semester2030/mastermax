import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:like_button/like_button.dart';
import '../models/car_model.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../favorites/providers/favorites_provider.dart' as global_favorites;
import '../../auth/providers/auth_state.dart';

class CarListItem extends StatelessWidget {
  final CarModel car;
  final VoidCallback? onTap;

  const CarListItem({
    required this.car,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: car.mainImage,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Theme.of(context).colorScheme.surface,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Theme.of(context).colorScheme.surface,
                      child: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    // تحسين الأداء
                    // ✅ إزالة memCacheWidth/memCacheHeight للحفاظ على الدقة الكاملة
                    // memCacheWidth: null,
                    // memCacheHeight: null,
                  ),
                ),
                // ✅ شارة عدد الصور في السيارة (إن وجدت صور متعددة)
                if (car.images.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${car.images.length}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.surface,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (car.has360View || car.hasInteriorView || car.virtualTourUrl != null)
                  Positioned(
                    top: 8,
                    right: 48, // ترك مساحة لأيقونة المفضلة
                    child: Row(
                      children: [
                        if (car.has360View)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ColorUtils.withOpacity(Theme.of(context).colorScheme.onSurface, 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.view_in_ar,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '360°',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        if (car.hasInteriorView) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ColorUtils.withOpacity(Theme.of(context).colorScheme.onSurface, 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.airline_seat_recline_normal,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 16,
                            ),
                          ),
                        ],
                        if (car.virtualTourUrl != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ColorUtils.withOpacity(Theme.of(context).colorScheme.onSurface, 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.panorama_horizontal,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                // ✅ زر المفضلة (قلب) للسيارة - يستخدم FavoritesProvider الموحد
                Positioned(
                  top: 8,
                  right: 8,
                  child: Consumer2<global_favorites.FavoritesProvider, AuthState>(
                    builder: (context, favoritesProvider, authState, _) {
                      final userId = authState.user?.id;
                      final isFavorite = userId != null && favoritesProvider.isFavorite(car.id);
                      return LikeButton(
                        isLiked: isFavorite,
                        size: 26,
                        circleColor: const CircleColor(
                          start: AppColors.error,
                          end: AppColors.primary,
                        ),
                        bubblesColor: const BubblesColor(
                          dotPrimaryColor: AppColors.error,
                          dotSecondaryColor: AppColors.primary,
                        ),
                        onTap: (liked) async {
                          if (userId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يجب تسجيل الدخول أولاً لحفظ السيارة في المفضلة'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return false;
                          }
                          if (liked) {
                            await favoritesProvider.removeFromFavorites(car.id, userId);
                          } else {
                            await favoritesProvider.addToFavorites(car, userId);
                          }
                          return !liked;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '﷼ ${car.price}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          car.address,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
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