import 'package:flutter/material.dart';
import '../models/spotlight_category.dart';
import 'spotlight_feed_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class SpotlightCategoryScreen extends StatelessWidget {
  const SpotlightCategoryScreen({super.key});

  void _navigateToFeed(BuildContext context, SpotlightCategory category) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SpotlightFeedScreen(category: category),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background with Stars
          const StarryBackground(),
          
          // Main Content
          Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // App Title with Icon
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                          ).createShader(bounds),
                          child: Text(
                            'أضواء ماكس',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: ColorUtils.withOpacity(AppColors.primary, 0.26),
                                  blurRadius: 12,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Categories Icons
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CategoryIcon(
                            title: 'السيارات',
                            subtitle: '12 شاهد أحدث السيارات',
                            icon: Icons.directions_car,
                            onTap: () => _navigateToFeed(context, SpotlightCategory.cars),
                          ),
                          const SizedBox(height: 32),
                          
                          _CategoryIcon(
                            title: 'العقارات',
                            subtitle: '8 استكشف العقارات',
                            icon: Icons.home,
                            onTap: () => _navigateToFeed(context, SpotlightCategory.realEstate),
                          ),
                          const SizedBox(height: 32),
                          
                          _CategoryIcon(
                            title: 'الكل',
                            subtitle: '20 جميع العروض',
                            icon: Icons.grid_view,
                            onTap: () => _navigateToFeed(context, SpotlightCategory.mixed),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryIcon({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(AppColors.primary, 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: ColorUtils.withOpacity(AppColors.textSecondary, 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class StarryBackground extends StatelessWidget {
  const StarryBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            AppColors.backgroundSecondary,
          ],
        ),
      ),
    );
  }
} 