import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:mastermax_2030/src/core/theme/app_colors.dart';
import 'package:mastermax_2030/src/core/utils/color_utils.dart';

class EnhancedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool showControls;

  const EnhancedVideoPlayer({
    required this.videoUrl, super.key,
    this.autoPlay = true,
    this.showControls = true,
  });

  @override
  State<EnhancedVideoPlayer> createState() => _EnhancedVideoPlayerState();
}

class _EnhancedVideoPlayerState extends State<EnhancedVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    await _controller.initialize();
    if (widget.autoPlay) {
      await _controller.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: VideoPlayer(_controller),
            ),
          ),
          if (widget.showControls) ...[
            const SizedBox(height: 8),
            _buildControls(),
          ],
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: AppColors.text,
            ),
            onPressed: () {
              setState(() {
                if (_isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
                _isPlaying = !_isPlaying;
              });
            },
          ),
          Expanded(
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppColors.textLight,
                bufferedColor: ColorUtils.withOpacity(AppColors.surface, 0.1),
                backgroundColor: AppColors.disabled,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _volume > 0 ? Icons.volume_up : Icons.volume_off,
              color: AppColors.text,
            ),
            onPressed: () {
              setState(() {
                if (_volume > 0) {
                  _volume = 0;
                  _controller.setVolume(0);
                } else {
                  _volume = 1.0;
                  _controller.setVolume(1.0);
                }
              });
            },
          ),
        ],
      ),
    );
  }
} 