import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../models/spotlight_category.dart';
import '../widgets/video_list.dart';
import '../../settings/screens/settings_screen.dart';
import 'add_video_screen.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';

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
        return 'أضواء ماكس';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.spotlightBackground,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
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
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
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
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddVideoScreen(category: category),
              ),
            );
          },
          backgroundColor: AppColors.spotlightBorder,
          tooltip: 'إضافة محتوى جديد',
          child: const Icon(Icons.add, color: AppColors.spotlightBackground),
        ),
      ),
    );
  }
} 