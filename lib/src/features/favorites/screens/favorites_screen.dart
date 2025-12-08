import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../../properties/models/property_model.dart';
import '../../auth/providers/auth_state.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/animations/animated_background.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.filter == 'property' ? 'العقارات المفضلة' : 
          widget.filter == 'car' ? 'السيارات المفضلة' : 
          'المفضلة',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.secondary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: AnimatedGradientBackground(
        colors: [
          colorScheme.primary,
          colorScheme.secondary,
          colorScheme.error,
        ],
        child: AnimatedShapesBackground(
          color: colorScheme.secondary,
          numberOfShapes: 15,
          child: Consumer<FavoritesProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return Center(
                  child: custom_animations.AnimatedGlow(
                    glowColor: colorScheme.secondary,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
                    ),
                  ),
                );
              }

              if (provider.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      custom_animations.AnimatedGlow(
                        glowColor: colorScheme.secondary,
                        child: Icon(
                          Icons.error_outline,
                          size: 64,
                          color: colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        provider.error!,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      custom_animations.AnimatedScale(
                        onTap: () {
                          final userId = context.read<AuthState>().user?.id;
                          if (userId != null) {
                            provider.loadFavorites(userId);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.secondary,
                                colorScheme.secondary.withAlpha(204), // 0.8 * 255
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'إعادة المحاولة',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final favorites = widget.filter != null
                  ? provider.favorites.where((p) => 
                      p.type.toString().split('.').last == widget.filter).toList()
                  : provider.favorites;

              if (favorites.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      custom_animations.AnimatedGlow(
                        glowColor: colorScheme.secondary,
                        child: Icon(
                          Icons.favorite_border,
                          size: 64,
                          color: colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'قائمة المفضلة فارغة',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimary,
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
                  final property = favorites[index];
                  return _FavoriteCard(
                    property: property,
                    onRemove: () => provider.removeFromFavorites(property.id),
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback onRemove;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _FavoriteCard({
    required this.property,
    required this.onRemove,
    required this.colorScheme,
    required this.textTheme,
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
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withAlpha(51),
              colorScheme.secondary.withAlpha(51),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.secondary.withAlpha(77),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withAlpha(26),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.secondary.withAlpha(26),
                        colorScheme.secondary.withAlpha(13),
                      ],
                    ),
                  ),
                  child: property.images.isNotEmpty
                    ? Image.network(
                        property.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: colorScheme.primary.withAlpha(51),
                            child: Icon(
                              Icons.image_not_supported,
                              color: colorScheme.secondary,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: colorScheme.primary.withAlpha(51),
                        child: Icon(
                          Icons.home,
                          color: colorScheme.secondary,
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
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.secondary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      property.description,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              custom_animations.AnimatedScale(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.secondary.withAlpha(26),
                    border: Border.all(
                      color: colorScheme.secondary.withAlpha(77),
                    ),
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: colorScheme.secondary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 