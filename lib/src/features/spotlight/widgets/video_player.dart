import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as vp;

class VideoPlayer extends StatefulWidget {
  final String url;
  final bool autoPlay;

  const VideoPlayer({
    required this.url, super.key,
    this.autoPlay = false,
  });

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  late vp.VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = vp.VideoPlayerController.asset(
      widget.url,
    );
    try {
      await _controller.initialize();
      if (widget.autoPlay) {
        await _controller.play();
        _isPlaying = true;
      }
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller.play() : _controller.pause();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!_isInitialized) {
      return Center(
        child: CircularProgressIndicator(
          color: colorScheme.primary,
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // الفيديو
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: vp.VideoPlayer(_controller),
          ),

          // زر التشغيل/الإيقاف
          if (!_isPlaying)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow,
                color: colorScheme.primary,
                size: 32,
              ),
            ),

          // شريط التقدم
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: vp.VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: vp.VideoProgressColors(
                playedColor: colorScheme.primary,
                bufferedColor: colorScheme.surface.withOpacity(0.2),
                backgroundColor: colorScheme.surface.withOpacity(0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 