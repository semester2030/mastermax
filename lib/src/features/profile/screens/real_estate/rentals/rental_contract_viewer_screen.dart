import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/theme/app_colors.dart';

/// شاشة لعرض ملف عقد الإيجار داخل التطبيق
///
/// تعرض ملف PDF/Word داخل WebView
/// تدعم مشاركة الملف
/// تتبع الثيم الموحد للتطبيق
class RentalContractViewerScreen extends StatefulWidget {
  final String contractUrl;
  final String rentalTitle;
  final String? fileName;

  const RentalContractViewerScreen({
    super.key,
    required this.contractUrl,
    required this.rentalTitle,
    this.fileName,
  });

  @override
  State<RentalContractViewerScreen> createState() => _RentalContractViewerScreenState();
}

class _RentalContractViewerScreenState extends State<RentalContractViewerScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // ✅ للويب: فتح الملف مباشرة في نافذة جديدة
      _openInBrowser();
      setState(() {
        _isLoading = false;
      });
    } else {
      _initWebView();
    }
  }

  Future<void> _openInBrowser() async {
    // ✅ للويب: فتح الملف مباشرة في المتصفح
    try {
      String urlToLoad = widget.contractUrl;
      
      if (widget.contractUrl.toLowerCase().endsWith('.pdf') || 
          widget.contractUrl.contains('.pdf')) {
        urlToLoad = 'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.contractUrl)}&embedded=true';
      } else if (widget.contractUrl.toLowerCase().endsWith('.doc') || 
                 widget.contractUrl.toLowerCase().endsWith('.docx') ||
                 widget.contractUrl.contains('.doc')) {
        urlToLoad = 'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.contractUrl)}&embedded=true';
      }

      final uri = Uri.parse(urlToLoad);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح الملف في المتصفح'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _initWebView() {
    // ✅ للموبايل: استخدام WebView
    String urlToLoad = widget.contractUrl;
    
    if (widget.contractUrl.toLowerCase().endsWith('.pdf') || 
        widget.contractUrl.contains('.pdf')) {
      urlToLoad = 'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.contractUrl)}&embedded=true';
    } else if (widget.contractUrl.toLowerCase().endsWith('.doc') || 
               widget.contractUrl.toLowerCase().endsWith('.docx') ||
               widget.contractUrl.contains('.doc')) {
      urlToLoad = 'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.contractUrl)}&embedded=true';
    }
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = error.description;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('docs.google.com') || 
                request.url.contains('firebasestorage.googleapis.com')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(urlToLoad));
  }

  Future<void> _shareContract() async {
    try {
      HapticFeedback.mediumImpact();
      
      // ✅ إصلاح مشكلة sharePositionOrigin على iOS
      ShareParams params;
      
      if (Platform.isIOS) {
        // ✅ الحصول على position من AppBar أو استخدام قيمة افتراضية
        Rect? sharePositionOrigin;
        try {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
          }
        } catch (e) {
          debugPrint('Error getting sharePositionOrigin: $e');
        }
        
        sharePositionOrigin ??= const Rect.fromLTWH(0, 0, 1, 1);
        
        params = ShareParams(
          text: 'عقد إيجار: ${widget.rentalTitle}\n${widget.contractUrl}',
          subject: 'عقد إيجار - ${widget.rentalTitle}',
          sharePositionOrigin: sharePositionOrigin,
        );
      } else {
        params = ShareParams(
          text: 'عقد إيجار: ${widget.rentalTitle}\n${widget.contractUrl}',
          subject: 'عقد إيجار - ${widget.rentalTitle}',
        );
      }
      
      await SharePlus.instance.share(params);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء المشاركة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        shadowColor: colorScheme.primary.withValues(alpha: 0.3),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عرض عقد الإيجار',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.fileName != null)
              Text(
                widget.fileName!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          // ✅ مشاركة الملف
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareContract,
            tooltip: 'مشاركة',
          ),
          // ✅ فتح في المتصفح
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: 'فتح في المتصفح',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ✅ WebView/iframe لعرض الملف
          if (!_hasError)
            kIsWeb
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.description,
                            size: 64,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'تم فتح الملف في نافذة جديدة',
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'إذا لم يفتح الملف تلقائياً، اضغط على الزر أدناه',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _openInBrowser,
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text('فتح الملف'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : (_controller != null
                    ? WebViewWidget(controller: _controller!)
                    : const SizedBox())
          else
            // ✅ رسالة خطأ
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'حدث خطأ في تحميل الملف',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        _initWebView();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openInBrowser,
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('فتح في المتصفح'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // ✅ Loading indicator
          if (_isLoading && !_hasError)
            Container(
              color: AppColors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحميل الملف...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
