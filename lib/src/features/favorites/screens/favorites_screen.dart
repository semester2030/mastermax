import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../../properties/models/property_model.dart';
import '../../cars/models/car_model.dart';
import '../../spotlight/models/video_model.dart';
import '../../auth/providers/auth_state.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import 'favorites_screen_cards.dart';

class FavoritesScreen extends StatefulWidget {
  final String? filter;
  
  const FavoritesScreen({
    super.key,
    this.filter,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthState>().user?.id;
      if (userId != null) {
        context.read<FavoritesProvider>().loadFavorites(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        title: Text(
          widget.filter == 'property' ? 'العقارات المفضلة' : 
          widget.filter == 'car' ? 'السيارات المفضلة' : 
          'المفضلة',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.background,
            ],
          ),
        ),
        child: Consumer<FavoritesProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.error!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        final userId = context.read<AuthState>().user?.id;
                        if (userId != null) {
                          provider.loadFavorites(userId);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                      ),
                      child: const Text(
                        'إعادة المحاولة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final favorites = widget.filter != null
                ? provider.favorites.where((item) {
                    if (item is PropertyModel) {
                      return widget.filter == 'property';
                    } else if (item is CarModel) {
                      return widget.filter == 'car';
                    } else if (item is VideoModel) {
                      return widget.filter == 'video';
                    }
                    return false;
                  }).toList()
                : provider.favorites;

            if (favorites.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'قائمة المفضلة فارغة',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final item = favorites[index];
                final userId = context.read<AuthState>().user?.id;
                
                if (item is PropertyModel) {
                  return _FavoriteCard(
                    property: item,
                    onRemove: userId != null 
                        ? () => provider.removeFromFavorites(item.id, userId)
                        : null,
                  );
                } else if (item is CarModel) {
                  return FavoriteCarCard(
                    car: item,
                    onRemove: userId != null
                        ? () => provider.removeFromFavorites(item.id, userId)
                        : null,
                  );
                } else if (item is VideoModel) {
                  return FavoriteVideoCard(
                    video: item,
                    onRemove: userId != null
                        ? () => provider.removeFromFavorites(item.id, userId)
                        : null,
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onRemove;

  const _FavoriteCard({
    required this.property,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return custom_animations.AnimatedScale(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/property-details',
          arguments: {'id': property.id},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryLight,
          ),
          boxShadow: AppColors.defaultShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 100,
                  height: 100,
                  color: AppColors.background,
                  child: property.images.isNotEmpty
                    ? Image.network(
                        property.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.background,
                            child: const Icon(
                              Icons.image_not_supported,
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: AppColors.background,
                        child: const Icon(
                          Icons.home,
                          color: AppColors.textSecondary,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      property.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.favorite,
                    color: AppColors.error,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 