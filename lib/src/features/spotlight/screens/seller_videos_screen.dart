import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/video_list.dart';
import '../providers/video_provider.dart';
import '../../../core/theme/app_colors.dart';

/// شاشة عرض فيديوهات البائع (seller)
class SellerVideosScreen extends StatefulWidget {
  final String sellerId;
  final String sellerName;

  const SellerVideosScreen({
    required this.sellerId,
    required this.sellerName,
    super.key,
  });

  @override
  State<SellerVideosScreen> createState() => _SellerVideosScreenState();
}

class _SellerVideosScreenState extends State<SellerVideosScreen> {
  int _videoCount = 0;
  bool _isLoadingCount = true;

  @override
  void initState() {
    super.initState();
    _loadVideoCount();
    _loadVideos();
  }

  Future<void> _loadVideoCount() async {
    try {
      final videoProvider = context.read<VideoProvider>();
      final count = await videoProvider.getSellerVideoCount(widget.sellerId);
      if (mounted) {
        setState(() {
          _videoCount = count;
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading video count: $e');
      if (mounted) {
        setState(() {
          _isLoadingCount = false;
        });
      }
    }
  }

  Future<void> _loadVideos() async {
    final videoProvider = context.read<VideoProvider>();
    await videoProvider.loadSellerVideos(widget.sellerId);
  }

  String _getCountText(int count) {
    if (count == 0) return 'لا توجد مقاطع';
    if (count == 1) return 'مقطع واحد';
    if (count == 2) return 'مقطعان';
    if (count <= 10) return '$count مقاطع';
    return '$count مقطع';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'رجوع',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.sellerName,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isLoadingCount)
              Text(
                _getCountText(_videoCount),
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      body: VideoList(
        type: null, // عرض جميع أنواع الفيديوهات
        showAll: true,
        sellerId: widget.sellerId, // ✅ تمرير sellerId لتحميل فيديوهات البائع فقط
      ),
    );
  }
}
