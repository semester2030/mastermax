import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_model.dart';
import '../widgets/car_video_player.dart';
import '../providers/video_provider.dart';
import '../../../core/theme/app_colors.dart';

class VideoList extends StatefulWidget {
  final String? initialVideoId;
  final VideoType? type;
  final bool showAll;

  const VideoList({
    super.key,
    this.initialVideoId,
    this.type,
    this.showAll = false,
  });

  @override
  State<VideoList> createState() => _VideoListState();
}

class _VideoListState extends State<VideoList> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    final provider = context.read<VideoProvider>();
    if (widget.showAll) {
      await provider.loadMixedVideos();
    } else if (widget.type == VideoType.car) {
      await provider.loadCarVideos();
    } else {
      await provider.loadRealEstateVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Consumer<VideoProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.textLight, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    style: const TextStyle(color: AppColors.textLight),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadVideos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textLight,
                      foregroundColor: AppColors.secondary,
                    ),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (provider.videos.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد فيديوهات متاحة',
                style: TextStyle(fontSize: 16, color: AppColors.textLight),
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: provider.videos.length,
            itemBuilder: (context, index) {
              final video = provider.videos[index];
              return CarVideoPlayer(
                video: video,
                isLiked: provider.likedVideos.contains(video.id),
                onLike: () => provider.toggleLike(video.id),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
} 