import 'package:flutter/material.dart';
import '../services/check_videos_status_service.dart';
import '../../../core/theme/app_colors.dart';

/// شاشة للتحقق من حالة الفيديوهات
class CheckVideosStatusScreen extends StatefulWidget {
  const CheckVideosStatusScreen({super.key});

  @override
  State<CheckVideosStatusScreen> createState() => _CheckVideosStatusScreenState();
}

class _CheckVideosStatusScreenState extends State<CheckVideosStatusScreen> {
  final CheckVideosStatusService _service = CheckVideosStatusService();
  VideosStatusReport? _report;
  bool _isLoading = false;
  String? _error;

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
    });

    try {
      final report = await _service.checkAllVideos();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _report = report;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'خطأ في التحقق: $e';
        });
      }
    }
  }

  Future<void> _fixBrokenUrls() async {
    if (_report == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإصلاح'),
        content: const Text(
          'سيتم إصلاح URLs المكسورة باستخدام cloudflareVideoId الموجود في Firestore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إصلاح'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _service.fixBrokenUrls();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.success ? 'نجح الإصلاح' : 'فشل الإصلاح'),
            content: result.success
                ? Text('تم إصلاح ${result.fixed} فيديو\nفشل: ${result.failed}')
                : Text('خطأ: ${result.error}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _checkStatus(); // إعادة التحقق
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'خطأ في الإصلاح: $e';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حالة الفيديوهات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _checkStatus,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _checkStatus,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _report == null
                  ? const Center(child: Text('لا توجد بيانات'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Firestore Status
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Firestore',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildStatusRow(
                                    'إجمالي الفيديوهات',
                                    '${_report!.firestore.total}',
                                  ),
                                  _buildStatusRow(
                                    'URLs من Firebase',
                                    '${_report!.firestore.firebaseUrls}',
                                    color: AppColors.warning,
                                  ),
                                  _buildStatusRow(
                                    'URLs من Cloudflare',
                                    '${_report!.firestore.cloudflareUrls}',
                                    color: AppColors.success,
                                  ),
                                  _buildStatusRow(
                                    'URLs مكسورة',
                                    '${_report!.firestore.brokenUrls}',
                                    color: AppColors.error,
                                  ),
                                  _buildStatusRow(
                                    'لديها cloudflareVideoId',
                                    '${_report!.firestore.hasCloudflareId}',
                                    color: AppColors.primary,
                                  ),
                                  if (_report!.firestore.brokenUrls > 0 &&
                                      _report!.firestore.hasCloudflareId > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: ElevatedButton(
                                        onPressed: _fixBrokenUrls,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                        ),
                                        child: const Text('إصلاح URLs المكسورة'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Firebase Storage Status
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Firebase Storage',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildStatusRow(
                                    'عدد الملفات',
                                    '${_report!.firebaseStorage.totalFiles}',
                                  ),
                                  _buildStatusRow(
                                    'الحجم الإجمالي',
                                    _report!.firebaseStorage.totalSizeFormatted,
                                  ),
                                  if (_report!.firebaseStorage.error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'خطأ: ${_report!.firebaseStorage.error}',
                                        style: const TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Cloudflare Status
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cloudflare Stream',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildStatusRow(
                                    'مُهيأ',
                                    _report!.cloudflare.isConfigured ? 'نعم' : 'لا',
                                    color: _report!.cloudflare.isConfigured
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                  if (_report!.cloudflare.note != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _report!.cloudflare.note!,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  if (_report!.cloudflare.error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'خطأ: ${_report!.cloudflare.error}',
                                        style: const TextStyle(
                                          color: AppColors.error,
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

  Widget _buildStatusRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
