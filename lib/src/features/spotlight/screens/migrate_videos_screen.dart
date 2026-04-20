import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/migrate_videos_service.dart';
import '../../../core/theme/app_colors.dart';

/// شاشة نقل الفيديوهات من Firebase إلى Cloudflare
class MigrateVideosScreen extends StatefulWidget {
  const MigrateVideosScreen({super.key});

  @override
  State<MigrateVideosScreen> createState() => _MigrateVideosScreenState();
}

class _MigrateVideosScreenState extends State<MigrateVideosScreen> {
  final MigrateVideosService _migrateService = MigrateVideosService();
  bool _isInitialized = false;
  bool _isMigrating = false;
  int _currentProgress = 0;
  int _totalVideos = 0;
  MigrationSummary? _summary;
  String? _error;
  bool _deleteFromFirebase = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isInitialized = false;
      _error = null;
    });

    try {
      final success = await _migrateService.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = success;
          if (!success) {
            _error = 'فشل في تهيئة الخدمة. تأكد من إعدادات Cloudflare.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'خطأ في التهيئة: $e';
        });
      }
    }
  }

  Future<void> _startMigration() async {
    if (!_isInitialized || _isMigrating) return;

    setState(() {
      _isMigrating = true;
      _currentProgress = 0;
      _totalVideos = 0;
      _summary = null;
      _error = null;
    });

    try {
      final summary = await _migrateService.migrateAllVideos(
        deleteFromFirebase: _deleteFromFirebase,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _currentProgress = current;
              _totalVideos = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isMigrating = false;
          _summary = summary;
        });

        // عرض النتيجة
        _showSummaryDialog(summary);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMigrating = false;
          _error = 'خطأ في النقل: $e';
        });
      }
    }
  }

  void _showSummaryDialog(MigrationSummary summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نتيجة النقل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إجمالي الفيديوهات: ${summary.total}'),
            const SizedBox(height: 8),
            Text(
              'نجح: ${summary.successful}',
              style: const TextStyle(color: AppColors.success),
            ),
            const SizedBox(height: 4),
            Text(
              'فشل: ${summary.failed}',
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 8),
            Text(
              'نسبة النجاح: ${(summary.successRate * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقل الفيديوهات إلى Cloudflare'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // حالة التهيئة
            if (!_isInitialized)
              Card(
                color: AppColors.warning.withOpacity(0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('جاري تهيئة الخدمة...'),
                    ],
                  ),
                ),
              ),

            // رسالة خطأ
            if (_error != null)
              Card(
                color: AppColors.error.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: AppColors.error),
                      const SizedBox(width: 16),
                      Expanded(child: Text(_error!)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // معلومات
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سيتم نقل جميع الفيديوهات من Firebase Storage إلى Cloudflare Stream.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• سيتم تحديث URLs في Firestore تلقائياً',
                    ),
                    const Text(
                      '• الفيديوهات القديمة ستبقى في Firebase (آمنة)',
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('حذف الفيديوهات من Firebase بعد النقل'),
                      subtitle: const Text(
                        '⚠️ تحذير: هذا الإجراء لا يمكن التراجع عنه',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _deleteFromFirebase,
                      onChanged: _isMigrating
                          ? null
                          : (value) {
                              setState(() {
                                _deleteFromFirebase = value ?? false;
                              });
                            },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // شريط التقدم
            if (_isMigrating)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'جاري النقل: $_currentProgress / $_totalVideos',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _totalVideos > 0
                            ? _currentProgress / _totalVideos
                            : 0,
                      ),
                    ],
                  ),
                ),
              ),

            // النتيجة
            if (_summary != null)
              Card(
                color: _summary!.failed == 0
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'النتيجة',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('إجمالي: ${_summary!.total}'),
                      Text(
                        'نجح: ${_summary!.successful}',
                        style: const TextStyle(color: AppColors.success),
                      ),
                      Text(
                        'فشل: ${_summary!.failed}',
                        style: const TextStyle(color: AppColors.error),
                      ),
                      Text(
                        'نسبة النجاح: ${(_summary!.successRate * 100).toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // زر البدء
            ElevatedButton(
              onPressed: _isInitialized && !_isMigrating
                  ? _startMigration
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'بدء النقل',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
