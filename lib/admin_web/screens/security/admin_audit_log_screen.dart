import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../src/core/theme/app_colors.dart';
import '../../../src/core/utils/color_utils.dart';
import '../../services/admin_audit_log_service.dart';
import '../../services/admin_audit_models.dart';
import '../../utils/audit_csv_download.dart';

String _formatDateTime(DateTime? t) {
  if (t == null) return '—';
  final y = t.year.toString().padLeft(4, '0');
  final mo = t.month.toString().padLeft(2, '0');
  final d = t.day.toString().padLeft(2, '0');
  final h = t.hour.toString().padLeft(2, '0');
  final mi = t.minute.toString().padLeft(2, '0');
  return '$y-$mo-$d $h:$mi';
}

String _actionLabelAr(String action) {
  switch (action) {
    case AdminAuditAction.verificationApproved:
      return 'قبول طلب تحقق';
    case AdminAuditAction.verificationRejected:
      return 'رفض طلب تحقق';
    case AdminAuditAction.auditExported:
      return 'تصدير سجل التدقيق';
    default:
      return action;
  }
}

String _csvCell(String? s) {
  if (s == null || s.isEmpty) return '';
  final t = s.replaceAll('"', '""');
  if (t.contains(',') || t.contains('\n') || t.contains('\r') || t.contains('"')) {
    return '"$t"';
  }
  return t;
}

/// عرض تفاعلي لسجل إجراءات الإدارة مع تصفية وتصدير CSV.
class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final AdminAuditLogService _audit = AdminAuditLogService();
  final TextEditingController _search = TextEditingController();
  int _streamEpoch = 0;
  _AuditViewFilter _filter = _AuditViewFilter.all;
  bool _exporting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AdminAuditLogRow> _applyFilters(List<AdminAuditLogRow> raw) {
    Iterable<AdminAuditLogRow> it = raw;
    switch (_filter) {
      case _AuditViewFilter.verification:
        it = it.where((r) => r.action.startsWith('verification.'));
        break;
      case _AuditViewFilter.exports:
        it = it.where((r) => r.action == AdminAuditAction.auditExported);
        break;
      case _AuditViewFilter.failures:
        it = it.where((r) => r.isFailure);
        break;
      case _AuditViewFilter.all:
        break;
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return it.toList();
    return it
        .where(
          (r) =>
              r.actorUid.toLowerCase().contains(q) ||
              r.actorEmail.toLowerCase().contains(q) ||
              r.action.toLowerCase().contains(q) ||
              r.targetType.toLowerCase().contains(q) ||
              r.targetId.toLowerCase().contains(q) ||
              r.summary.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final qs = await FirebaseFirestore.instance
          .collection(AdminAuditLogService.collectionName)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();
      final rows = _applyFilters(qs.docs.map(AdminAuditLogRow.fromDoc).toList());
      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد بيانات للتصدير بعد التصفية')),
          );
        }
        return;
      }
      final buf = StringBuffer('\uFEFF');
      buf.writeln(
        [
          'createdAt',
          'outcome',
          'action',
          'actorEmail',
          'actorUid',
          'targetType',
          'targetId',
          'summary',
          'metadataJson',
        ].join(','),
      );
      for (final r in rows) {
        final metaJson = r.metadata.isEmpty ? '' : jsonEncode(r.metadata);
        buf.writeln([
          _csvCell(_formatDateTime(r.createdAt)),
          _csvCell(r.outcome),
          _csvCell(r.action),
          _csvCell(r.actorEmail),
          _csvCell(r.actorUid),
          _csvCell(r.targetType),
          _csvCell(r.targetId),
          _csvCell(r.summary),
          _csvCell(metaJson),
        ].join(','));
      }
      final csv = buf.toString();
      await _audit.log(
        action: AdminAuditAction.auditExported,
        targetType: AdminAuditTargetType.auditLog,
        summary: 'تصدير CSV لعدد ${rows.length} سجل تدقيق (بعد التصفية)',
        metadata: {'rowCount': rows.length},
      );
      if (!mounted) return;
      final name = 'admin_audit_${DateTime.now().millisecondsSinceEpoch}.csv';
      downloadAuditCsv(name, csv);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تنزيل الملف ($name) وتسجيل عملية التصدير'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
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
                  'سجل إجراءات الإدارة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Tooltip(
                message: 'تحديث مباشر من Firestore',
                child: Icon(Icons.sensors_rounded, color: ColorUtils.withOpacity(AppColors.success, 0.9), size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'يُسجّل تلقائياً قبول ورفض طلبات التحقق، وتصدير هذا السجل. السجلات غير قابلة للتعديل أو الحذف من الواجهة.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'بحث: البريد، المعرف، نوع الهدف، الملخص…',
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('الكل'),
                selected: _filter == _AuditViewFilter.all,
                onSelected: (_) => setState(() => _filter = _AuditViewFilter.all),
              ),
              ChoiceChip(
                label: const Text('التحقق'),
                selected: _filter == _AuditViewFilter.verification,
                onSelected: (_) => setState(() => _filter = _AuditViewFilter.verification),
              ),
              ChoiceChip(
                label: const Text('التصدير'),
                selected: _filter == _AuditViewFilter.exports,
                onSelected: (_) => setState(() => _filter = _AuditViewFilter.exports),
              ),
              ChoiceChip(
                label: const Text('فشل فقط'),
                selected: _filter == _AuditViewFilter.failures,
                onSelected: (_) => setState(() => _filter = _AuditViewFilter.failures),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _exporting ? null : _exportCsv,
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.file_download_outlined, size: 20),
                label: Text(_exporting ? 'جاري التصدير…' : 'تصدير CSV'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<AdminAuditLogRow>>(
              key: ValueKey(_streamEpoch),
              stream: _audit.watchRecent(limit: 200),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SelectableText(
                          snap.error.toString(),
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
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
                final filtered = _applyFilters(snap.data!);
                if (filtered.isEmpty) {
                  return const Center(child: Text('لا توجد سجلات مطابقة'));
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
                        side: BorderSide(
                          color: ColorUtils.withOpacity(
                            r.isFailure ? AppColors.error : AppColors.primary,
                            0.14,
                          ),
                        ),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: r.isFailure
                                ? ColorUtils.withOpacity(AppColors.error, 0.12)
                                : ColorUtils.withOpacity(AppColors.success, 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            r.isFailure ? 'فشل' : 'نجاح',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: r.isFailure ? AppColors.error : AppColors.success,
                            ),
                          ),
                        ),
                        title: Text(
                          _actionLabelAr(r.action),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDateTime(r.createdAt),
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                r.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        children: [
                          _DetailRow(label: 'الإجراء (مفتاح)', value: r.action),
                          _DetailRow(label: 'الهدف', value: '${r.targetType}${r.targetId.isEmpty ? '' : ' / ${r.targetId}'}'),
                          _DetailRow(label: 'البريد', value: r.actorEmail.isEmpty ? '—' : r.actorEmail),
                          SelectableText(
                            'المُنفّذ: ${r.actorUid}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if (r.metadata.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text('بيانات إضافية', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            SelectableText(
                              JsonEncoder.withIndent('  ').convert(r.metadata),
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final text = [
                                r.action,
                                r.outcome,
                                _formatDateTime(r.createdAt),
                                r.summary,
                                r.actorUid,
                                if (r.metadata.isNotEmpty) jsonEncode(r.metadata),
                              ].join('\n');
                              await Clipboard.setData(ClipboardData(text: text));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم نسخ ملخص السجل')),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('نسخ الملخص'),
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

enum _AuditViewFilter { all, verification, exports, failures }

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
