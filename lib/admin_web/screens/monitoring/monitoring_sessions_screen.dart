import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../src/core/theme/app_colors.dart';
import '../../../src/core/utils/color_utils.dart';
import '../../services/monitoring_service.dart';

String _formatDurationAr(int totalSeconds) {
  if (totalSeconds <= 0) return '—';
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  if (m >= 60) {
    final h = m ~/ 60;
    final mm = m % 60;
    return '$hس $mmد';
  }
  if (m > 0) return '$mد $sث';
  return '$sث';
}

String _formatDateTime(DateTime? t) {
  if (t == null) return '—';
  final y = t.year.toString().padLeft(4, '0');
  final mo = t.month.toString().padLeft(2, '0');
  final d = t.day.toString().padLeft(2, '0');
  final h = t.hour.toString().padLeft(2, '0');
  final mi = t.minute.toString().padLeft(2, '0');
  return '$y-$mo-$d $h:$mi';
}

/// جلسات المستخدم في التطبيق (مستندات `app_sessions`) — تحديث مباشر وتصفية.
class MonitoringSessionsScreen extends StatefulWidget {
  const MonitoringSessionsScreen({super.key});

  @override
  State<MonitoringSessionsScreen> createState() => _MonitoringSessionsScreenState();
}

class _MonitoringSessionsScreenState extends State<MonitoringSessionsScreen> {
  final MonitoringService _svc = MonitoringService();
  final TextEditingController _search = TextEditingController();
  _SessionFilter _filter = _SessionFilter.all;
  int _streamEpoch = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AppSessionRow> _applyFilter(List<AppSessionRow> raw) {
    final q = _search.text.trim().toLowerCase();
    Iterable<AppSessionRow> it = raw;
    switch (_filter) {
      case _SessionFilter.open:
        it = it.where((r) => r.isOpen);
        break;
      case _SessionFilter.closed:
        it = it.where((r) => !r.isOpen);
        break;
      case _SessionFilter.all:
        break;
    }
    if (q.isEmpty) return it.toList();
    return it
        .where(
          (r) =>
              r.email.toLowerCase().contains(q) ||
              r.userId.toLowerCase().contains(q) ||
              r.platform.toLowerCase().contains(q) ||
              r.id.toLowerCase().contains(q),
        )
        .toList();
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
                  'جلسات المستخدم',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Tooltip(
                message: 'البث مباشر من Firestore',
                child: Icon(Icons.sensors_rounded, color: ColorUtils.withOpacity(AppColors.success, 0.9), size: 22),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'تُسجَّل الجلسة عند عودة التطبيق للمقدمة وتُحدَّث عند الإيقاف المؤقت. المعطيات من آخر 200 جلسة؛ للمستخدمين المسجّلين فقط.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'بحث: البريد، معرّف المستخدم، المنصّة، رقم الجلسة…',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('الكل'),
                selected: _filter == _SessionFilter.all,
                onSelected: (_) => setState(() => _filter = _SessionFilter.all),
              ),
              ChoiceChip(
                label: const Text('نشطة'),
                selected: _filter == _SessionFilter.open,
                onSelected: (_) => setState(() => _filter = _SessionFilter.open),
              ),
              ChoiceChip(
                label: const Text('منتهية'),
                selected: _filter == _SessionFilter.closed,
                onSelected: (_) => setState(() => _filter = _SessionFilter.closed),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<AppSessionRow>>(
              key: ValueKey(_streamEpoch),
              stream: _svc.watchRecentSessions(limit: 200),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(snap.error.toString(), style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => _streamEpoch++),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                final filtered = _applyFilter(snap.data!);
                if (filtered.isEmpty) {
                  return const Center(child: Text('لا توجد جلسات مطابقة'));
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = filtered[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: ColorUtils.withOpacity(AppColors.primary, 0.12)),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: r.isOpen
                                ? ColorUtils.withOpacity(AppColors.success, 0.14)
                                : ColorUtils.withOpacity(AppColors.textSecondary, 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            r.isOpen ? 'نشطة' : 'منتهية',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: r.isOpen ? AppColors.success : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        title: Text(
                          r.email.isEmpty ? '(بدون بريد)' : r.email,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(Icons.devices_rounded, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(r.platform, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 16),
                              Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(_formatDurationAr(r.foregroundSeconds), style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        children: [
                          SelectableText(
                            'معرّف الجلسة: ${r.id}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            'المستخدم: ${r.userId.isEmpty ? '—' : r.userId}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'بدأت: ${_formatDateTime(r.startedAt)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'انتهت: ${_formatDateTime(r.endedAt)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: r.id));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم نسخ معرّف الجلسة')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('نسخ معرّف الجلسة'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _SessionFilter { all, open, closed }
