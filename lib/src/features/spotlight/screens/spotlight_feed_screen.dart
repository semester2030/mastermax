import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_model.dart';
import '../models/spotlight_category.dart';
import '../widgets/video_list.dart';
import '../../settings/screens/settings_screen.dart';
import '../../auth/providers/auth_state.dart';
import '../../auth/utils/listing_vertical_guard.dart';
import 'add_video_screen.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_brand.dart';
import '../config/spotlight_monetization_config.dart';

class SpotlightFeedScreen extends StatelessWidget {
  final String? initialVideoId;
  final SpotlightCategory category;

  const SpotlightFeedScreen({
    required this.category, super.key,
    this.initialVideoId,
  });

  String get _title {
    switch (category) {
      case SpotlightCategory.cars:
        return 'السيارات';
      case SpotlightCategory.realEstate:
        return 'العقارات';
      case SpotlightCategory.mixed:
        return AppBrand.displayName;
      case SpotlightCategory.featured:
        return 'العروض المميزة';
    }
  }

  VideoType? get _type {
    switch (category) {
      case SpotlightCategory.cars:
        return VideoType.car;
      case SpotlightCategory.realEstate:
        return VideoType.realEstate;
      case SpotlightCategory.mixed:
        return null;
      case SpotlightCategory.featured:
        return null;
    }
  }

  bool _mayUploadSpotlight(AuthState auth) {
    if (!auth.isAuthenticated) return false;
    if (auth.isAdmin) return true;
    final t = auth.user?.type ?? auth.userType;
    switch (category) {
      case SpotlightCategory.cars:
        return ListingVerticalGuard.mayPublishCars(t, isAdmin: false);
      case SpotlightCategory.realEstate:
        return ListingVerticalGuard.mayPublishProperties(t, isAdmin: false);
      case SpotlightCategory.mixed:
      case SpotlightCategory.featured:
        return ListingVerticalGuard.mayPublishCars(t, isAdmin: false) ||
            ListingVerticalGuard.mayPublishProperties(t, isAdmin: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, auth, _) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
          ),
          child: Scaffold(
            backgroundColor: AppColors.transparent,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: AppColors.transparent,
              elevation: 0,
              title: Text(
                _title,
                style: const TextStyle(
                  color: AppColors.spotlightText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.history,
                    color: AppColors.spotlightText,
                    size: 24,
                  ),
                  tooltip: 'شاهدتها سابقاً',
                  onPressed: () {
                    Navigator.pushNamed(context, '/spotlight/history');
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.camera_enhance,
                    color: AppColors.spotlightText,
                    size: 24,
                  ),
                  tooltip: 'الكاميرا الاحترافية',
                  onPressed: () {
                    Navigator.pushNamed(context, Routes.camera);
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.map,
                    color: AppColors.spotlightText,
                    size: 24,
                  ),
                  tooltip: 'الخريطة',
                  onPressed: () {
                    Navigator.pushNamed(context, '/map');
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.settings,
                    color: AppColors.spotlightText,
                    size: 24,
                  ),
                  tooltip: 'الإعدادات',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
                if (SpotlightMonetizationConfig.subscriptionsAndPaymentsEnabled)
                  IconButton(
                    icon: Stack(
                      children: [
                        const Icon(
                          Icons.workspace_premium,
                          color: AppColors.accent,
                          size: 28,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 8,
                              minHeight: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    tooltip: 'الاشتراكات',
                    onPressed: () {
                      Navigator.pushNamed(context, '/subscription');
                    },
                  ),
              ],
            ),
            body: VideoList(
              initialVideoId: initialVideoId,
              type: _type,
              showAll: category == SpotlightCategory.mixed,
            ),
            floatingActionButton: _mayUploadSpotlight(auth)
                ? FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddVideoScreen(category: category),
                        ),
                      );
                    },
                    backgroundColor: AppColors.spotlightBorder,
                    tooltip: 'إضافة محتوى جديد',
                    child: const Icon(
                      Icons.add,
                      color: AppColors.spotlightBackground,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
} 