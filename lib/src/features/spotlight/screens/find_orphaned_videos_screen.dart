import 'package:flutter/material.dart';
import '../services/find_orphaned_videos_service.dart';
import '../../../core/theme/app_colors.dart';

/// شاشة للعثور على الفيديوهات المتبقية
class FindOrphanedVideosScreen extends StatefulWidget {
  const FindOrphanedVideosScreen({super.key});

  @override
  State<FindOrphanedVideosScreen> createState() => _FindOrphanedVideosScreenState();
}

class _FindOrphanedVideosScreenState extends State<FindOrphanedVideosScreen> {
  final FindOrphanedVideosService _service = FindOrphanedVideosService();
  OrphanedVideosReport? _report;
  bool _isLoading = false;
  String? _error;

  Future<void> _findOrphanedVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
    });

    try {
      final report = await _service.findOrphanedVideos();
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل في البحث: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteOrphanedVideos() async {
    if (_report == null || _report!.orphanedVideos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد فيديوهات متبقية للحذف'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف ${_report!.orphanedVideos.length} فيديو متبقي؟\n\n'
          'هذه الفيديوهات موجودة في Firestore لكن الملفات غير موجودة في Cloudflare أو Firebase Storage.\n\n'
          'لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // عرض loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await _service.deleteOrphanedVideos(dryRun: false);

    if (!mounted) return;
    Navigator.pop(context); // إغلاق loading

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );

    // إعادة البحث
    _findOrphanedVideos();
  }

  @override
  void initState() {
    super.initState();
    _findOrphanedVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث عن الفيديوهات المتبقية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _findOrphanedVideos,
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
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _findOrphanedVideos,
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
                          // ملخص
                          Card(
                            color: AppColors.primary.withOpacity(0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ملخص',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildSummaryItem('إجمالي الفيديوهات', '${_report!.total}'),
                                  _buildSummaryItem('فيديوهات صالحة', '${_report!.valid}', AppColors.success),
                                  _buildSummaryItem('فيديوهات متبقية', '${_report!.orphaned}', AppColors.error),
                                  _buildSummaryItem('فقط Cloudflare', '${_report!.cloudflareOnly}'),
                                  _buildSummaryItem('فقط Firebase', '${_report!.firebaseOnly}'),
                                  _buildSummaryItem('URLs مكسورة', '${_report!.brokenUrls}', AppColors.error),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // زر حذف الفيديوهات المتبقية
                          if (_report!.orphanedVideos.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: _deleteOrphanedVideos,
                              icon: const Icon(Icons.delete_forever),
                              label: Text('حذف ${_report!.orphanedVideos.length} فيديو متبقي'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: AppColors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // قائمة الفيديوهات المتبقية
                          if (_report!.orphanedVideos.isNotEmpty) ...[
                            const Text(
                              'الفيديوهات المتبقية',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._report!.orphanedVideos.map((video) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: AppColors.error.withOpacity(0.1),
                              child: ListTile(
                                title: Text(
                                  video.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('النوع: ${video.typeDisplay}'),
                                    Text('المصدر: ${video.uploadSource}'),
                                    Text('URL: ${video.url.isEmpty ? "فارغ" : video.url}'),
                                    if (video.cloudflareVideoId != null)
                                      Text('Cloudflare ID: ${video.cloudflareVideoId}'),
                                  ],
                                ),
                                trailing: const Icon(Icons.warning, color: AppColors.error),
                              ),
                            )),
                          ],
                          
                          // قائمة الفيديوهات الصالحة
                          if (_report!.validVideos.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'الفيديوهات الصالحة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._report!.validVideos.take(10).map((video) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(video.title),
                                subtitle: Text('النوع: ${video.typeDisplay} - المصدر: ${video.uploadSource}'),
                                trailing: const Icon(Icons.check_circle, color: AppColors.success),
                              ),
                            )),
                            if (_report!.validVideos.length > 10)
                              Text('... و ${_report!.validVideos.length - 10} فيديو آخر'),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSummaryItem(String label, String value, [Color? color]) {
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
