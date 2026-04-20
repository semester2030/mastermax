import 'package:flutter/material.dart';

import '../../../src/core/theme/app_colors.dart';
import '../../../src/core/utils/color_utils.dart';
import '../../services/monitoring_service.dart';

/// سجل فشل رفع الوسائط (فيديو / صورة / مصغّر).
class MonitoringMediaFailuresScreen extends StatefulWidget {
  const MonitoringMediaFailuresScreen({super.key});

  @override
  State<MonitoringMediaFailuresScreen> createState() => _MonitoringMediaFailuresScreenState();
}

class _MonitoringMediaFailuresScreenState extends State<MonitoringMediaFailuresScreen> {
  final MonitoringService _svc = MonitoringService();
  bool _loading = true;
  List<MediaFailureRow> _rows = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.recentFailures(limit: 120);
      if (mounted) {
        setState(() {
          _rows = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'فشل رفع الوسائط',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'يُسجّل التطبيق تلقائياً عند فشل رفع فيديو (Cloudflare) أو صورة (Cloudflare Images) أو صورة مصغّرة.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: AppColors.error)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                          ],
                        ),
                      )
                    : _rows.isEmpty
                        ? const Center(child: Text('لا توجد أعطال مسجّلة بعد'))
                        : ListView.separated(
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final r = _rows[i];
                              return ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                title: Row(
                                  children: [
                                    Icon(
                                      r.mediaKind.contains('video')
                                          ? Icons.videocam_off_rounded
                                          : Icons.broken_image_outlined,
                                      color: AppColors.error,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${r.mediaKind} · ${r.context}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(_formatTime(r.createdAt)),
                                      backgroundColor: ColorUtils.withOpacity(AppColors.primary, 0.1),
                                      labelStyle: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    r.errorMessage,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                                  ),
                                ),
                                children: [
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: SelectableText(
                                      'المستخدم: ${r.userId.isEmpty ? '—' : r.userId}\nالبريد: ${r.email.isEmpty ? '—' : r.email}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ),
                                  if (r.detail != null && r.detail!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Text('تفاصيل إضافية:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      r.detail!,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
