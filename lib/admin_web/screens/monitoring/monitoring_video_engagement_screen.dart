import 'package:flutter/material.dart';

import '../../../src/core/theme/app_colors.dart';
import '../../../src/core/utils/color_utils.dart';
import '../../services/monitoring_service.dart';

/// الأكثر والأقل مشاهدة لفيديوهات السبوتلايت.
class MonitoringVideoEngagementScreen extends StatefulWidget {
  const MonitoringVideoEngagementScreen({super.key});

  @override
  State<MonitoringVideoEngagementScreen> createState() => _MonitoringVideoEngagementScreenState();
}

class _MonitoringVideoEngagementScreenState extends State<MonitoringVideoEngagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final MonitoringService _svc = MonitoringService();
  bool _loading = true;
  List<VideoEngagementRow> _top = [];
  List<VideoEngagementRow> _least = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Future.wait<List<VideoEngagementRow>>([
        _svc.topVideosByViews(limit: 50),
        _svc.leastVideosByViews(limit: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _top = res[0];
        _least = res[1];
        _loading = false;
      });
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
                  'تفاعل الفيديو (المشاهدات)',
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
          const SizedBox(height: 12),
          TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'الأكثر مشاهدة'),
              Tab(text: 'الأقل مشاهدة'),
            ],
          ),
          const SizedBox(height: 12),
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
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _VideoTable(rows: _top, highlightHot: true),
                          _VideoTable(rows: _least, highlightHot: false),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _VideoTable extends StatelessWidget {
  const _VideoTable({required this.rows, required this.highlightHot});

  final List<VideoEngagementRow> rows;
  final bool highlightHot;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('لا توجد بيانات'));
    }
    final maxV = rows.map((r) => r.viewsCount).fold<int>(0, (a, b) => a > b ? a : b).clamp(1, 1 << 30);

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(ColorUtils.withOpacity(AppColors.primary, 0.06)),
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('العنوان')),
              DataColumn(label: Text('البائع')),
              DataColumn(label: Text('المعرف')),
              DataColumn(label: Text('النوع')),
              DataColumn(label: Text('مشاهدات')),
              DataColumn(label: Text('إعجابات')),
              DataColumn(label: Text('نسبة')),
            ],
            rows: [
              for (var i = 0; i < rows.length; i++)
                DataRow(
                  color: WidgetStateProperty.resolveWith((states) {
                    if (!highlightHot) return null;
                    if (rows[i].viewsCount >= maxV * 0.5 && rows[i].viewsCount > 10) {
                      return ColorUtils.withOpacity(AppColors.success, 0.08);
                    }
                    return null;
                  }),
                  cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(SizedBox(width: 220, child: Text(rows[i].title, maxLines: 2, overflow: TextOverflow.ellipsis))),
                    DataCell(SizedBox(width: 140, child: Text(rows[i].sellerName, overflow: TextOverflow.ellipsis))),
                    DataCell(
                      SelectableText(
                        rows[i].sellerId.isEmpty ? '—' : rows[i].sellerId,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(Text(rows[i].type)),
                    DataCell(Text('${rows[i].viewsCount}')),
                    DataCell(Text('${rows[i].likesCount}')),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: rows[i].viewsCount / maxV,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          color: AppColors.primary,
                          backgroundColor: ColorUtils.withOpacity(AppColors.primary, 0.12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
