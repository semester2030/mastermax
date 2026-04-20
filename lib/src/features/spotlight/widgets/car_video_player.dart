import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/video_model.dart';
import '../providers/video_provider.dart';
import '../../settings/providers/app_user_settings_provider.dart';
import '../services/video_history_service.dart';
import '../../auth/providers/auth_state.dart';
import 'package:mastermax_2030/src/core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../chat/chat_screen_route_args.dart';
import '../../../core/utils/color_utils.dart';

class CarVideoPlayer extends StatefulWidget {
  final VideoModel video;
  final bool isLiked;
  final VoidCallback onLike;
  final bool shouldPreload; // تحميل الفيديو فقط عند الحاجة

  const CarVideoPlayer({
    required this.video, 
    required this.isLiked, 
    required this.onLike,
    this.shouldPreload = true, // افتراضياً نحمّل الفيديو
    super.key,
  });

  @override
  State<CarVideoPlayer> createState() => _CarVideoPlayerState();
}

class _CarVideoPlayerState extends State<CarVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isPlaying = true;
  bool _showControls = true;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasIncrementedViews = false; // لتجنب زيادة المشاهدات أكثر من مرة
  bool _hasAddedToHistory = false; // ✅ لتجنب إضافة المشاهدة أكثر من مرة
  int _retryCount = 0; // عدد محاولات إعادة التحميل
  static const int _maxRetries = 5; // الحد الأقصى للمحاولات
  bool _isRetrying = false; // لمنع محاولات متعددة متزامنة
  final VideoHistoryService _historyService = VideoHistoryService(); // ✅ خدمة حفظ التاريخ

  @override
  void initState() {
    super.initState();
    // تحميل الفيديو فقط إذا كان shouldPreload = true
    if (widget.shouldPreload) {
      _initializeVideo();
    } else {
      // عرض thumbnail فقط
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    // عرض thumbnail أولاً
    setState(() {
      _isLoading = true;
    });
  }

  Future<void> _initializeVideo() async {
    if (_isLoading || _isInitialized || _isRetrying) return; // منع التحميل المتعدد
    
    setState(() {
      _isLoading = true;
    });

    try {
      final userSettings = context.read<AppUserSettingsProvider>();
      await userSettings.ensureLoaded();
      if (!mounted) return;
      final videoUrl = widget.video.url;
      
      // ✅ استخدام video_player لجميع أنواع الفيديو (يدعم HLS و MP4)
      // video_player يدعم HLS (.m3u8) و Cloudflare Stream تلقائياً
      if (videoUrl.startsWith('http://') || videoUrl.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          // video_player يدعم HLS تلقائياً
        );
      } else {
        // استخدام asset للفيديوهات المحلية
        _controller = VideoPlayerController.asset(videoUrl);
      }
      
      // مهلة أطول لـ HLS/Cloudflare على شبكات بطيئة أو مقاطع ثقيلة
      await _controller!.initialize().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException('Timeout loading video');
        },
      );
      
      _controller!.addListener(_videoListener);
      _controller!.setLooping(true);

      final autoPlay = userSettings.autoPlayVideos;
      if (autoPlay) {
        await _controller!.play();
      } else {
        await _controller!.pause();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
          _isPlaying = autoPlay;
          _retryCount = 0; // إعادة تعيين عداد المحاولات عند النجاح
        });
        if (autoPlay) {
          _incrementViewsIfNeeded();
          _addToHistoryIfNeeded();
        }
      }
    } catch (error) {
      debugPrint('Error initializing video player: $error');
      debugPrint('Video URL: ${widget.video.url}');
      debugPrint('Retry count: $_retryCount/$_maxRetries');
      
      // ✅ التحقق من نوع الخطأ
      final errorString = error.toString();
      final is404Error = errorString.contains('404') || 
                        errorString.contains('File Not Found') ||
                        errorString.contains('not found');
      
      // ✅ التحقق من عمر الفيديو (إذا كان حديث الرفع، قد يكون في مرحلة المعالجة)
      final isRecentVideo =
          DateTime.now().difference(widget.video.createdAt).inMinutes < 5;
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // ✅ إذا كان خطأ 404 وفيديو حديث، نعيد المحاولة بصمت (بدون إزعاج المستخدم)
        if (is404Error && isRecentVideo && _retryCount < _maxRetries) {
          _retryCount++;
          final delaySeconds = _calculateRetryDelay(_retryCount);
          debugPrint('🔄 Video may still be processing. Retrying in ${delaySeconds}s (attempt $_retryCount/$_maxRetries)...');
          
          // إعادة المحاولة بصمت (بدون SnackBar)
          Future.delayed(Duration(seconds: delaySeconds), () {
            if (mounted && !_isInitialized && _retryCount <= _maxRetries) {
              _retryVideoLoadSilent();
            }
          });
          return; // لا نعرض رسالة خطأ للمستخدم
        }
        
        // ✅ إذا تجاوزنا الحد الأقصى للمحاولات أو لم يكن خطأ 404 حديث
        if (_retryCount >= _maxRetries) {
          // لا نعرض رسالة خطأ إضافية - فقط نعرض thumbnail
          debugPrint('❌ Max retries reached. Video may still be processing on Cloudflare.');
          return;
        }
        
        // ✅ محاولة إعادة التحميل بعد تأخير قصير (للأخطاء الأخرى)
        _retryCount++;
        final delaySeconds = _calculateRetryDelay(_retryCount);
        
        Future.delayed(Duration(seconds: delaySeconds), () {
          if (mounted && !_isInitialized && _retryCount < _maxRetries) {
            _retryVideoLoad();
          }
        });
        
        // ✅ عرض رسالة خطأ فقط إذا لم يكن خطأ 404 حديث
        if (!is404Error || !isRecentVideo) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                is404Error && isRecentVideo
                    ? 'الفيديو قيد المعالجة. جاري إعادة المحاولة...'
                    : 'فشل في تحميل الفيديو. جاري إعادة المحاولة...',
              ),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'إعادة المحاولة',
                onPressed: _retryVideoLoad,
              ),
            ),
          );
        }
      }
    }
  }
  
  /// حساب تأخير إعادة المحاولة (exponential backoff)
  int _calculateRetryDelay(int retryCount) {
    // 2, 4, 8, 16, 32 ثانية
    return (2 * (1 << (retryCount - 1))).clamp(2, 32);
  }

  Future<void> _retryVideoLoad() async {
    if (_isRetrying) return;
    _isRetrying = true;
    
    try {
      if (_controller != null) {
        if (_controller!.value.isInitialized) {
          await _controller!.dispose();
        }
        _controller = null;
      }
      
      setState(() {
        _isInitialized = false;
        _isLoading = false;
      });
      
      await _initializeVideo();
    } catch (e) {
      debugPrint('Retry failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // لا نعرض رسالة خطأ إذا تجاوزنا الحد الأقصى
        if (_retryCount < _maxRetries) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل في تحميل الفيديو. يرجى التحقق من الاتصال بالإنترنت.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      _isRetrying = false;
    }
  }
  
  /// إعادة تحميل صامتة (بدون إزعاج المستخدم)
  Future<void> _retryVideoLoadSilent() async {
    if (_isRetrying) return;
    _isRetrying = true;
    
    try {
      if (_controller != null) {
        if (_controller!.value.isInitialized) {
          await _controller!.dispose();
        }
        _controller = null;
      }
      
      setState(() {
        _isInitialized = false;
        _isLoading = true; // نعرض loading بصمت
      });
      
      await _initializeVideo();
    } catch (e) {
      debugPrint('Silent retry failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      _isRetrying = false;
    }
  }

  void _togglePlay() {
    if (!_isInitialized) {
      // إذا لم يتم تحميل الفيديو بعد، حمّله الآن
      if (!_isLoading) {
        _initializeVideo();
      }
      return;
    }

    final willPlay = !_isPlaying;
    setState(() {
      _isPlaying = willPlay;
      if (_controller != null) {
        willPlay ? _controller!.play() : _controller!.pause();
      }
    });
    if (willPlay) {
      _incrementViewsIfNeeded();
      _addToHistoryIfNeeded();
    }
  }

  void _videoListener() {
    if (_controller != null && mounted) {
      setState(() {
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  /// نسبة عرض/ارتفاع آمنة للعرض (تفضّل [aspectRatio] على [size] لأنها تعكس الدوران بشكل أفضل من TikTok/HLS).
  double _displayAspectRatio(VideoPlayerController c) {
    final v = c.value;
    final r = v.aspectRatio;
    if (r.isFinite && r > 0.02) {
      return r.clamp(0.02, 50.0);
    }
    final s = v.size;
    if (s.height > 0 && s.width > 0) {
      return (s.width / s.height).clamp(0.02, 50.0);
    }
    return 9 / 16;
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

  Future<void> _shareVideo([BuildContext? anchorButtonContext]) async {
    final url = widget.video.url.trim();
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد رابط لهذا المقطع للمشاركة')),
        );
      }
      return;
    }

    final text =
        'شاهد هذا الفيديو: ${widget.video.title}\n$url';

    Rect? origin;
    final anchor = anchorButtonContext;
    if (anchor != null && anchor.mounted) {
      final box = anchor.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        origin = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    origin ??= () {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        return box.localToGlobal(Offset.zero) & box.size;
      }
      return Rect.fromLTWH(0, 0, 1, 1);
    }();

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: widget.video.title,
          // iOS (خصوصاً iPad): بدون مصدر موضع قد لا تظهر ورقة المشاركة أو تفشل بصمت
          sharePositionOrigin: kIsWeb ? null : origin,
        ),
      );
    } catch (e, st) {
      debugPrint('SharePlus.share failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر فتح المشاركة. حاول مرة أخرى. ($e)')),
        );
      }
    }
  }

  void _openMap() {
    final p = widget.video.location;
    const eps = 1e-5;
    if (p.latitude.abs() < eps && p.longitude.abs() < eps) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يُحدد موقع جغرافي لهذا المقطع على الخريطة'),
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      Routes.spotlightLocationMap,
      arguments: {'video': widget.video},
    );
  }

  void _openChat() {
    final sellerId = widget.video.sellerId?.trim();
    if (sellerId == null || sellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يتوفر حساب البائع لهذا المقطع')),
      );
      return;
    }
    final auth = context.read<AuthState>();
    final uid = auth.user?.id;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول لمراسلة صاحب الإعلان')),
      );
      return;
    }
    final typeStr = widget.video.type == VideoType.car ? 'car' : 'real_estate';
    if (uid == sellerId) {
      Navigator.pushNamed(
        context,
        Routes.chat,
        arguments: {
          ChatScreenRouteArgs.sellerInboxForVideo: true,
          ChatScreenRouteArgs.videoId: widget.video.id,
          ChatScreenRouteArgs.videoTitle: widget.video.title,
        },
      );
      return;
    }
    Navigator.pushNamed(
      context,
      Routes.chat,
      arguments: {
        ChatScreenRouteArgs.sellerId: sellerId,
        ChatScreenRouteArgs.videoId: widget.video.id,
        ChatScreenRouteArgs.propertyType: typeStr,
        ChatScreenRouteArgs.videoTitle: widget.video.title,
        ChatScreenRouteArgs.sellerName: widget.video.sellerName,
      },
    );
  }

  /// زيادة عدد المشاهدات (مرة واحدة فقط)
  void _incrementViewsIfNeeded() {
    if (!_hasIncrementedViews) {
      _hasIncrementedViews = true;
      final videoProvider = context.read<VideoProvider>();
      videoProvider.incrementViewsCount(widget.video.id);
    }
  }

  /// ✅ حفظ المشاهدة في التاريخ تلقائياً (مرة واحدة فقط)
  void _addToHistoryIfNeeded() {
    if (!_hasAddedToHistory) {
      _hasAddedToHistory = true;
      // حفظ المشاهدة بشكل غير متزامن (لا ننتظر النتيجة)
      _historyService.addToHistory(
        widget.video.id,
        widget.video.title.isNotEmpty ? widget.video.title : 'بدون عنوان',
      ).catchError((e) {
        debugPrint('Error adding to history: $e');
        // لا نعرض خطأ للمستخدم - هذا ليس حرجاً
      });
    }
  }

  /// التحقق من أن المستخدم هو صاحب الفيديو
  bool _isVideoOwner() {
    final authState = context.read<AuthState>();
    final currentUserId = authState.user?.id;
    return currentUserId != null && currentUserId == widget.video.sellerId;
  }

  /// حذف الفيديو
  Future<void> _deleteVideo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الفيديو؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final videoProvider = context.read<VideoProvider>();
      final success = await videoProvider.deleteVideo(widget.video.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الفيديو بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(videoProvider.error ?? 'فشل في حذف الفيديو'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  /// تعديل الفيديو
  void _editVideo() {
    Navigator.pushNamed(
      context,
      '/spotlight/edit/${widget.video.id}',
      arguments: widget.video,
    );
  }

  /// تنسيق الأرقام (1.2ك، 1.5م)
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}م';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}ك';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        // ✅ خلفية داكنة أفضل للفيديو (مثل يوتيوب / تيك توك)
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // الفيديو أو Thumbnail
            if (_isInitialized && _controller != null && _controller!.value.isInitialized)
              // نفس منطق AspectRatio في شاشة إضافة الفيديو — أوضح من FittedBox+size لبعض HLS/التيكتوك
              Center(
                child: AspectRatio(
                  aspectRatio: _displayAspectRatio(_controller!),
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (widget.video.thumbnail.isNotEmpty)
              // عرض thumbnail أولاً
              Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.video.thumbnail,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.video_library,
                          color: AppColors.white,
                          size: 64,
                        ),
                      );
                    },
                  ),
                  Center(
                    child: GestureDetector(
                      onTap: _initializeVideo,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: ColorUtils.withOpacity(AppColors.primaryDark, 0.72),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: AppColors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              const ColoredBox(color: Colors.black),

            if (_isLoading && !_isInitialized)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: AppColors.white),
                      const SizedBox(height: 16),
                      Text(
                        'جاري تحميل المقطع...',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color: ColorUtils.withOpacity(Colors.black, 0.8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // تراكب التحكم (بدون لون موحّد على كامل الفيديو — كان يظهر كطبقة بنفسجية)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Stack(
                  children: [
                    // معلومات الفيديو — تدرّج أسفل الشاشة (تحت الأزرار في الترتيب حتى لا تسرق الضغطات)
                    Positioned(
                      left: 0,
                      right: 80,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 40, 88, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.video.sellerName != null && widget.video.sellerName!.isNotEmpty && widget.video.sellerId != null && widget.video.sellerId!.isNotEmpty) ...[
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/spotlight/seller/${widget.video.sellerId}',
                                      arguments: {
                                        'sellerId': widget.video.sellerId!,
                                        'sellerName': widget.video.sellerName ?? 'غير معروف',
                                      },
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.person,
                                        color: AppColors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        widget.video.sellerName!,
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                          shadows: [
                                            Shadow(blurRadius: 4, color: Colors.black45),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text(
                                widget.video.title,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(blurRadius: 6, color: Colors.black54),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.video.description,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 16,
                                  shadows: [
                                    Shadow(blurRadius: 4, color: Colors.black45),
                                  ],
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
                                    color: ColorUtils.withOpacity(AppColors.primaryDark, 0.75),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${widget.video.price} ريال',
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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
                              color: ColorUtils.withOpacity(AppColors.primaryDark, 0.72),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: AppColors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // أزرار التحكم الجانبية — في الأعلى في الـ Stack لتصل إليها الضغطات أولاً
                    Positioned(
                      right: 16,
                      bottom: MediaQuery.of(context).size.height * 0.2,
                      child: Column(
                        children: [
                          Column(
                            children: [
                              _buildActionButton(
                                icon: Icons.favorite,
                                color: widget.isLiked ? AppColors.error : AppColors.white,
                                onPressed: widget.onLike,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatNumber(widget.video.likesCount),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Selector<AppUserSettingsProvider, bool>(
                            selector: (_, s) => s.showViewsCount,
                            builder: (context, showViews, __) {
                              if (!showViews) return const SizedBox.shrink();
                              return Column(
                                children: [
                                  _buildActionButton(
                                    icon: Icons.remove_red_eye,
                                    onPressed: () {},
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatNumber(widget.video.viewsCount),
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                                    ),
                                  ),
                                ],
                              );
                            },
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
                          Builder(
                            builder: (shareCtx) => _buildActionButton(
                              icon: Icons.share,
                              onPressed: () => _shareVideo(shareCtx),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildActionButton(
                            icon: Icons.location_on,
                            onPressed: _openMap,
                          ),
                          if (_isVideoOwner()) ...[
                            const SizedBox(height: 16),
                            _buildActionButton(
                              icon: Icons.edit,
                              color: AppColors.primary,
                              onPressed: _editVideo,
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              icon: Icons.delete,
                              color: AppColors.error,
                              onPressed: _deleteVideo,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
    Color color = AppColors.white,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(AppColors.primaryDark, 0.72),
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
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }
} 