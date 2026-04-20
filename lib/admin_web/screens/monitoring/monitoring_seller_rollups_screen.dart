import 'package:flutter/material.dart';

import '../../../src/core/theme/app_colors.dart';
import '../../../src/core/utils/color_utils.dart';
import '../../services/monitoring_service.dart';

/// تجميع أداء البائعين/الشركات من عيّنة فيديوهات حديثة.
class MonitoringSellerRollupsScreen extends StatefulWidget {
  const MonitoringSellerRollupsScreen({super.key});

  @override
  State<MonitoringSellerRollupsScreen> createState() => _MonitoringSellerRollupsScreenState();
}

class _MonitoringSellerRollupsScreenState extends State<MonitoringSellerRollupsScreen> {
  final MonitoringService _svc = MonitoringService();
  bool _loading = true;
  List<SellerRollupRow> _rows = [];
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
      final list = await _svc.sellerRollups(videoSampleLimit: 400);
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
                  'الشركات والبائعون (الفيديو)',
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
            'يُحسب من أحدث 400 مقطع في السبوتلايت: عدد المقاطع ومجموع المشاهدات لكل معرّف بائع. للتوسيع لاحقاً يمكن جدولة تجميع يومي في Cloud Functions.',
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
                        ? const Center(child: Text('لا توجد بيانات'))
                        : LayoutBuilder(
                            builder: (context, c) {
                              final maxViews = _rows.first.totalViews.clamp(1, 1 << 30);
                              return ListView.separated(
                                itemCount: _rows.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final r = _rows[i];
                                  final ratio = r.totalViews / maxViews;
                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(color: ColorUtils.withOpacity(AppColors.primary, 0.12)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: AppColors.primaryLight,
                                                child: Text(
                                                  '${i + 1}',
                                                  style: const TextStyle(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      r.sellerName,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    SelectableText(
                                                      r.sellerId,
                                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${r.totalViews} مشاهدة',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${r.videoCount} مقطع',
                                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: ratio.clamp(0.0, 1.0),
                                              minHeight: 10,
                                              color: AppColors.primary,
                                              backgroundColor: ColorUtils.withOpacity(AppColors.primary, 0.1),
                                            ),
                                          ),
                                        ],
                                      ),
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
