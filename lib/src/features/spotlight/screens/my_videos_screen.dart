import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_model.dart';
import '../providers/video_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../../auth/utils/listing_vertical_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../widgets/car_video_player.dart';
import '../../favorites/providers/favorites_provider.dart';

class MyVideosScreen extends StatefulWidget {
  const MyVideosScreen({super.key});

  @override
  State<MyVideosScreen> createState() => _MyVideosScreenState();
}

class _MyVideosScreenState extends State<MyVideosScreen> {
  bool _mayUploadSpotlight(AuthState auth) {
    if (!auth.isAuthenticated) return false;
    if (auth.isAdmin) return true;
    final t = auth.user?.type ?? auth.userType;
    return ListingVerticalGuard.mayPublishCars(t, isAdmin: false) ||
        ListingVerticalGuard.mayPublishProperties(t, isAdmin: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyVideos();
    });
  }

  Future<void> _loadMyVideos() async {
    final authState = context.read<AuthState>();
    final userId = authState.user?.id;
    if (userId != null) {
      final videoProvider = context.read<VideoProvider>();
      await videoProvider.getUserVideos(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final userId = authState.user?.id;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('فيديوهاتي'),
        ),
        body: const Center(
          child: Text('يجب تسجيل الدخول لعرض فيديوهاتك'),
        ),
      );
    }

    final canUpload = _mayUploadSpotlight(authState);

    return Scaffold(
      appBar: AppBar(
        title: const Text('فيديوهاتي'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        actions: [
          if (canUpload)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.pushNamed(context, '/spotlight/upload');
              },
              tooltip: 'إضافة فيديو جديد',
            ),
        ],
      ),
      body: Consumer<VideoProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    style: const TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMyVideos,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          // القائمة محمّلة أصلاً بـ userId من الخادم؛ لا نفلتر بـ sellerId فقط
          // (قد يكون sellerId فارغاً في مستندات قديمة).
          final myVideos = provider.videos.toList();

          if (myVideos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 80,
                    color: ColorUtils.withOpacity(AppColors.textPrimary, 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد فيديوهات',
                    style: TextStyle(
                      fontSize: 18,
                      color: ColorUtils.withOpacity(AppColors.textPrimary, 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ابدأ برفع فيديو جديد',
                    style: TextStyle(
                      fontSize: 14,
                      color: ColorUtils.withOpacity(AppColors.textPrimary, 0.4),
                    ),
                  ),
                  if (canUpload) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/spotlight/upload');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة فيديو جديد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textLight,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadMyVideos,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myVideos.length,
              itemBuilder: (context, index) {
                final video = myVideos[index];
                return _buildVideoCard(context, video, provider);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, VideoModel video, VideoProvider provider) {
    final favoritesProvider = context.read<FavoritesProvider>();
    final authState = context.read<AuthState>();
    final userId = authState.user?.id;
    final isLiked = userId != null && favoritesProvider.isFavorite(video.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: video.thumbnail.isNotEmpty
                  ? Image.network(
                      video.thumbnail,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppColors.background,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.background,
                          child: const Icon(Icons.video_library, size: 64),
                        );
                      },
                    )
                  : Container(
                      color: AppColors.background,
                      child: const Icon(Icons.video_library, size: 64),
                    ),
            ),
          ),
          // معلومات الفيديو
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        video.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // أزرار التعديل والحذف
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.pushNamed(
                            context,
                            '/spotlight/edit/${video.id}',
                            arguments: video,
                          );
                        } else if (value == 'delete') {
                          _showDeleteDialog(context, video, provider);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('تعديل'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('حذف', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (video.description.isNotEmpty)
                  Text(
                    video.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: ColorUtils.withOpacity(AppColors.textPrimary, 0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // عدد المشاهدات
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _formatNumber(video.viewsCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.withOpacity(AppColors.textPrimary, 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // عدد الإعجابات
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 16,
                          color: isLiked ? AppColors.error : ColorUtils.withOpacity(AppColors.textPrimary, 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatNumber(video.likesCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.withOpacity(AppColors.textPrimary, 0.6),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // السعر
                    if (video.price != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${video.price} ريال',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // زر المشاهدة
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            body: CarVideoPlayer(
                              video: video,
                              isLiked: isLiked,
                              onLike: () {
                                final favoritesProvider = context.read<FavoritesProvider>();
                                final authState = context.read<AuthState>();
                                final userId = authState.user?.id;
                                if (userId != null) {
                                  provider.toggleLike(video.id);
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('مشاهدة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, VideoModel video, VideoProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الفيديو؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.deleteVideo(video.id);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الفيديو بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  _loadMyVideos();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.error ?? 'فشل في حذف الفيديو'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}م';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}ك';
    }
    return number.toString();
  }
}
