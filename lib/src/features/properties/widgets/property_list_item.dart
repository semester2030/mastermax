import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:like_button/like_button.dart';
import '../models/property_model.dart';
import '../../favorites/providers/favorites_provider.dart' as global_favorites;
import '../../auth/providers/auth_state.dart';

class PropertyListItem extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onTap;

  const PropertyListItem({
    required this.property,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
                    imageUrl: property.images.first,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.error_outline, color: colorScheme.error),
                    ),
                    // تحسين الأداء
                    // ✅ إزالة memCacheWidth/memCacheHeight للحفاظ على الدقة الكاملة
                  ),
                ),
                // ✅ شارة عدد صور العقار
                if (property.images.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 14,
                            color: colorScheme.surface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${property.images.length}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.surface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (property.has360View || property.virtualTourUrl != null)
                  Positioned(
                    top: 8,
                    right: 48, // ترك مساحة لأيقونة المفضلة
                    child: Row(
                      children: [
                        if (property.has360View)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.view_in_ar,
                                  color: colorScheme.onSurface,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '360°',
                                  style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        if (property.virtualTourUrl != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.panorama_horizontal,
                              color: colorScheme.onSurface,
                              size: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                // ✅ زر المفضلة (قلب) للعقار - يستخدم FavoritesProvider الموحد
                Positioned(
                  top: 8,
                  right: 8,
                  child: Consumer2<global_favorites.FavoritesProvider, AuthState>(
                    builder: (context, favoritesProvider, authState, _) {
                      final userId = authState.user?.id;
                      final isFavorite = userId != null && favoritesProvider.isFavorite(property.id);
                      return LikeButton(
                        isLiked: isFavorite,
                        size: 26,
                        circleColor: CircleColor(
                          start: Theme.of(context).colorScheme.error,
                          end: Theme.of(context).colorScheme.primary,
                        ),
                        bubblesColor: BubblesColor(
                          dotPrimaryColor: Theme.of(context).colorScheme.error,
                          dotSecondaryColor: Theme.of(context).colorScheme.primary,
                        ),
                        onTap: (liked) async {
                          if (userId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يجب تسجيل الدخول أولاً لحفظ العقار في المفضلة'),
                                backgroundColor: Color(0xFFD32F2F),
                              ),
                            );
                            return false;
                          }
                          if (liked) {
                            await favoritesProvider.removeFromFavorites(property.id, userId);
                          } else {
                            await favoritesProvider.addToFavorites(property, userId);
                          }
                          return !liked;
                        },
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(context, property.status),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      property.status.arabicName,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                    property.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '﷼ ${property.price}',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getOfferTypeColor(context, property.offerType),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          property.offerType.arabicName,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPropertySpec(context, Icons.bed, '${property.rooms}'),
                      const SizedBox(width: 16),
                      _buildPropertySpec(context, Icons.bathroom, '${property.bathrooms}'),
                      const SizedBox(width: 16),
                      _buildPropertySpec(context, Icons.square_foot, '${property.area} م²'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: colorScheme.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.address,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
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

  Widget _buildPropertySpec(BuildContext context, IconData icon, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(BuildContext context, PropertyStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case PropertyStatus.available:
        return colorScheme.primary;
      case PropertyStatus.sold:
        return colorScheme.error;
      case PropertyStatus.rented:
        return colorScheme.secondary;
      case PropertyStatus.underContract:
        return colorScheme.tertiary;
      case PropertyStatus.suspended:
        return colorScheme.outline;
    }
  }

  Color _getOfferTypeColor(BuildContext context, OfferType type) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case OfferType.sale:
        return colorScheme.primaryContainer;
      case OfferType.rent:
        return colorScheme.secondaryContainer;
    }
  }
} 