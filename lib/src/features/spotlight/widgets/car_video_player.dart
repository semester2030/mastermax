import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/video_model.dart';
import 'package:mastermax_2030/src/core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class CarVideoPlayer extends StatefulWidget {
  final VideoModel video;
  final bool isLiked;
  final VoidCallback onLike;

  const CarVideoPlayer({
    required this.video, required this.isLiked, required this.onLike, super.key,
  });

  @override
  State<CarVideoPlayer> createState() => _CarVideoPlayerState();
}

class _CarVideoPlayerState extends State<CarVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isPlaying = true;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      widget.video.url,
    )..initialize().then((_) {
      if (mounted) {
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
      }
    });
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller.play() : _controller.pause();
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  Future<void> _makePhoneCall() async {
    if (widget.video.sellerPhone != null) {
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: widget.video.sellerPhone,
      );
      try {
        await launchUrl(launchUri);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن الاتصال في الوقت الحالي')),
          );
        }
      }
    }
  }

  void _shareVideo() {
    Share.share(
      'شاهد هذا الفيديو: ${widget.video.title}\n${widget.video.url}',
      subject: widget.video.title,
    );
  }

  void _openMap() {
    Navigator.pushNamed(
      context,
      '/map',
      arguments: {'selectedVideo': widget.video},
    );
  }

  void _openChat() {
    Navigator.pushNamed(context, '/chat');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // الفيديو
            if (_controller.value.isInitialized)
              VideoPlayer(_controller )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),

            // تراكب التحكم
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      ColorUtils.withOpacity(Colors.black, 0.5),
                      ColorUtils.withOpacity(Colors.black, 0.5),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // أزرار التحكم الجانبية
                    Positioned(
                      right: 16,
                      bottom: MediaQuery.of(context).size.height * 0.2,
                      child: Column(
                        children: [
                          _buildActionButton(
                            icon: Icons.favorite,
                            color: widget.isLiked ? AppColors.error : AppColors.textLight,
                            onPressed: widget.onLike,
                          ),
                          if (widget.video.sellerPhone != null) ...[
                            const SizedBox(height: 16),
                            _buildActionButton(
                              icon: Icons.phone,
                              onPressed: _makePhoneCall,
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildActionButton(
                            icon: Icons.chat_bubble_outline,
                            onPressed: _openChat,
                          ),
                          const SizedBox(height: 16),
                          _buildActionButton(
                            icon: Icons.share,
                            onPressed: _shareVideo,
                          ),
                          const SizedBox(height: 16),
                          _buildActionButton(
                            icon: Icons.location_on,
                            onPressed: _openMap,
                          ),
                        ],
                      ),
                    ),

                    // معلومات الفيديو
                    Positioned(
                      left: 16,
                      right: 72,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.video.title,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.video.description,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.video.price != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: ColorUtils.withOpacity(AppColors.secondary, 0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${widget.video.price} ريال',
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // زر التشغيل/الإيقاف
                    Center(
                      child: AnimatedOpacity(
                        opacity: _showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: ColorUtils.withOpacity(AppColors.secondary, 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: AppColors.textLight,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color color = AppColors.textLight,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(AppColors.secondary, 0.7),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
} 