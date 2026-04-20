import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/spotlight_category.dart';
import '../providers/video_provider.dart';
import '../../settings/providers/app_user_settings_provider.dart';
import 'spotlight_feed_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/constants/app_brand.dart';

class SpotlightCategoryScreen extends StatefulWidget {
  const SpotlightCategoryScreen({super.key});

  @override
  State<SpotlightCategoryScreen> createState() => _SpotlightCategoryScreenState();
}

class _SpotlightCategoryScreenState extends State<SpotlightCategoryScreen> with WidgetsBindingObserver {
  int _carsCount = 0;
  int _realEstateCount = 0;
  int _totalCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVideoCounts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // تحديث العدد عند العودة للتطبيق (قد يكون تم إضافة/حذف فيديو)
    if (state == AppLifecycleState.resumed) {
      _loadVideoCounts();
    }
  }

  Future<void> _loadVideoCounts() async {
    try {
      final userSettings = context.read<AppUserSettingsProvider>();
      final videoProvider = context.read<VideoProvider>();
      await userSettings.ensureLoaded();
      if (!mounted) return;
      await videoProvider.setVideoQuality(userSettings.videoQuality);

      // جلب عدد الفيديوهات لكل نوع
      final counts = await videoProvider.getAllVideoCounts();
      
      if (mounted) {
        setState(() {
          _carsCount = counts[SpotlightCategory.cars] ?? 0;
          _realEstateCount = counts[SpotlightCategory.realEstate] ?? 0;
          _totalCount = counts[SpotlightCategory.mixed] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading video counts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getCountText(int count) {
    if (count == 0) return 'لا توجد مقاطع';
    if (count == 1) return 'مقطع واحد';
    if (count == 2) return 'مقطعان';
    if (count <= 10) return 'مقاطع';
    return 'مقطع';
  }

  Future<void> _navigateToFeed(BuildContext context, SpotlightCategory category) async {
    await Navigator.push(
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
                            AppBrand.displayName,
                            style: TextStyle(
                              color: AppColors.textPrimary,
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
                            subtitle: _isLoading 
                                ? 'جاري التحميل...' 
                                : '$_carsCount ${_getCountText(_carsCount)}',
                            icon: Icons.directions_car,
                            onTap: () async {
                              await _navigateToFeed(context, SpotlightCategory.cars);
                              // تحديث العدد بعد العودة
                              _loadVideoCounts();
                            },
                          ),
                          const SizedBox(height: 32),
                          
                          _CategoryIcon(
                            title: 'العقارات',
                            subtitle: _isLoading 
                                ? 'جاري التحميل...' 
                                : '$_realEstateCount ${_getCountText(_realEstateCount)}',
                            icon: Icons.home,
                            onTap: () async {
                              await _navigateToFeed(context, SpotlightCategory.realEstate);
                              // تحديث العدد بعد العودة
                              _loadVideoCounts();
                            },
                          ),
                          const SizedBox(height: 32),
                          
                          _CategoryIcon(
                            title: 'الكل',
                            subtitle: _isLoading 
                                ? 'جاري التحميل...' 
                                : '$_totalCount ${_getCountText(_totalCount)}',
                            icon: Icons.grid_view,
                            onTap: () async {
                              await _navigateToFeed(context, SpotlightCategory.mixed);
                              // تحديث العدد بعد العودة
                              _loadVideoCounts();
                            },
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            ColorUtils.withOpacity(AppColors.primary, 0.06),
          ],
        ),
      ),
    );
  }
} 