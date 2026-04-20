import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_model.dart';
import '../widgets/car_video_player.dart';
import '../providers/video_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../../../core/theme/app_colors.dart';

class VideoList extends StatefulWidget {
  final String? initialVideoId;
  final VideoType? type;
  final bool showAll;
  final String? sellerId; // ✅ معامل جديد: معرف البائع

  const VideoList({
    super.key,
    this.initialVideoId,
    this.type,
    this.showAll = false,
    this.sellerId, // ✅ معامل اختياري
  });

  @override
  State<VideoList> createState() => _VideoListState();
}

class _VideoListState extends State<VideoList> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    // تأجيل تحميل الفيديوهات لتجنب setState أثناء build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideos();
    });
    
    // الاستماع لتغيير الصفحة لتحميل المزيد تلقائياً
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    if (!_pageController.hasClients) return;
    
    final currentPage = _pageController.page?.round() ?? 0;
    if (currentPage != _currentIndex) {
      _currentIndex = currentPage;
      _checkAndLoadMore();
    }
  }

  void _checkAndLoadMore() {
    final provider = context.read<VideoProvider>();
    // تحميل المزيد عند الوصول لآخر 3 فيديوهات
    if (_currentIndex >= provider.videos.length - 3 && !_isLoadingMore) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadVideos() async {
    final provider = context.read<VideoProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();
    final authState = context.read<AuthState>();
    final userId = authState.user?.id;
    
    // ربط VideoProvider مع FavoritesProvider
    if (userId != null) {
      provider.setFavoritesProvider(favoritesProvider, userId);
    }
    
    // ✅ إذا كان هناك sellerId، نحمّل فيديوهات البائع فقط
    if (widget.sellerId != null && widget.sellerId!.isNotEmpty) {
      await provider.loadSellerVideos(widget.sellerId!);
    } else if (widget.showAll) {
      await provider.loadMixedVideos();
    } else if (widget.type == VideoType.car) {
      await provider.loadCarVideos();
    } else {
      await provider.loadRealEstateVideos();
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final provider = context.read<VideoProvider>();
      
      // ✅ إذا كان هناك sellerId، لا نحمّل المزيد (لأن loadSellerVideos لا يدعم pagination حالياً)
      if (widget.sellerId != null && widget.sellerId!.isNotEmpty) {
        // لا يوجد pagination للبائع حالياً
        return;
      }
      
      if (widget.showAll) {
        await provider.loadMoreMixedVideos();
      } else if (widget.type == VideoType.car) {
        await provider.loadMoreCarVideos();
      } else {
        await provider.loadMoreRealEstateVideos();
      }
    } catch (e) {
      debugPrint('Error loading more videos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
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
            // تمرير سلس مثل Snapchat
            physics: const BouncingScrollPhysics(),
            itemCount: provider.videos.length + (_isLoadingMore ? 1 : 0), // إضافة صفحة للتحميل
            itemBuilder: (context, index) {
              // إذا وصلنا لنهاية القائمة، نعرض loading
              if (index >= provider.videos.length) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textLight,
                  ),
                );
              }
              
              final video = provider.videos[index];
              return CarVideoPlayer(
                key: ValueKey(video.id), // استخدام key لتحسين الأداء
                video: video,
                isLiked: provider.likedVideos.contains(video.id),
                onLike: () => provider.toggleLike(video.id),
                // تحميل الفيديو فقط إذا كان في النطاق المرئي (الحالي + التالي)
                shouldPreload: index <= _currentIndex + 1,
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