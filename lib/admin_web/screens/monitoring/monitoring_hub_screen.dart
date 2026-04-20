import 'package:flutter/material.dart';

import '../../../src/core/theme/app_colors.dart';
import '../../../src/core/utils/color_utils.dart';
import '../../services/monitoring_service.dart';

/// مركز المراقبة — نقطة دخول موحّدة للمؤشرات والروابط التفصيلية.
class MonitoringHubScreen extends StatefulWidget {
  const MonitoringHubScreen({super.key});

  @override
  State<MonitoringHubScreen> createState() => _MonitoringHubScreenState();
}

class _MonitoringHubScreenState extends State<MonitoringHubScreen> {
  final MonitoringService _svc = MonitoringService();
  bool _loading = true;
  int _videos = 0;
  int _users = 0;
  int _pendingVerification = 0;
  int _failures24h = 0;
  int _sessions24h = 0;
  int _avgSessionSec = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<int>([
        _svc.countCollection('spotlight_videos'),
        _svc.countCollection('users'),
        _svc.countPendingVerification(),
        _svc.countFailuresLast24Hours(),
      ]);
      final sessions = await _svc.recentSessions(limit: 200);
      if (!mounted) return;
      setState(() {
        _videos = results[0];
        _users = results[1];
        _pendingVerification = results[2];
        _failures24h = results[3];
        _sessions24h = _svc.countSessionsStartedLast24Hours(sessions);
        _avgSessionSec = _svc.averageForegroundSeconds(sessions);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDurationShort(int totalSeconds) {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'مركز المراقبة والتحليلات',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث',
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'متابعة تفاعل الفيديو، جلسات المستخدم، فشل الرفع، وأوزان البائعين — بيانات مباشرة من Firestore.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;
                        final cols = w > 1100 ? 4 : (w > 700 ? 2 : 1);
                        final tileW = (w - (cols - 1) * 16) / cols;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _KpiTile(
                              width: tileW,
                              icon: Icons.video_library_rounded,
                              label: 'فيديوهات السبوتلايت',
                              value: '$_videos',
                              tint: AppColors.primary,
                            ),
                            _KpiTile(
                              width: tileW,
                              icon: Icons.people_rounded,
                              label: 'حسابات المستخدمين',
                              value: '$_users',
                              tint: AppColors.textSecondary,
                            ),
                            _KpiTile(
                              width: tileW,
                              icon: Icons.pending_actions_rounded,
                              label: 'تحقق معلّق',
                              value: '$_pendingVerification',
                              tint: AppColors.primaryDark,
                            ),
                            _KpiTile(
                              width: tileW,
                              icon: Icons.error_outline_rounded,
                              label: 'فشل رفع (24 ساعة)',
                              value: '$_failures24h',
                              tint: _failures24h > 0 ? AppColors.error : AppColors.success,
                            ),
                            _KpiTile(
                              width: tileW,
                              icon: Icons.groups_rounded,
                              label: 'جلسات بدأت (24 ساعة)',
                              value: '$_sessions24h',
                              tint: AppColors.primary,
                            ),
                            _KpiTile(
                              width: tileW,
                              icon: Icons.hourglass_top_rounded,
                              label: 'متوسط مدة الجلسة',
                              value: _formatDurationShort(_avgSessionSec),
                              tint: AppColors.textSecondary,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'انتقل إلى التفاصيل',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _NavCard(
                      title: 'مشاهدات الفيديو',
                      subtitle: 'الأكثر والأقل مشاهدة، مع نوع المقطع والبائع',
                      icon: Icons.trending_up_rounded,
                      onTap: () => Navigator.of(context).pushNamed('/monitoring/videos'),
                    ),
                    _NavCard(
                      title: 'الشركات والبائعون',
                      subtitle: 'تجميع عدد المقاطع وإجمالي المشاهدات لكل بائع (عيّنة حديثة)',
                      icon: Icons.apartment_rounded,
                      onTap: () => Navigator.of(context).pushNamed('/monitoring/sellers'),
                    ),
                    _NavCard(
                      title: 'فشل رفع الفيديو والصور',
                      subtitle: 'سجل الأعطال المسجّل من التطبيق لمعالجة السلوك والأخطاء',
                      icon: Icons.cloud_off_rounded,
                      onTap: () => Navigator.of(context).pushNamed('/monitoring/failures'),
                    ),
                    _NavCard(
                      title: 'جلسات المستخدم',
                      subtitle: 'قائمة مباشرة مع بحث وتصفية؛ مدة المقدمة والمنصّة والبريد',
                      icon: Icons.timeline_rounded,
                      onTap: () => Navigator.of(context).pushNamed('/monitoring/sessions'),
                    ),
                    _NavCard(
                      title: 'التحليل الجغرافي',
                      subtitle: 'مدن وأحياء، فلترة عقار/سيارة/فيديو، بائعون، تصدير CSV وتجميعات تفاعلية',
                      icon: Icons.map_rounded,
                      onTap: () => Navigator.of(context).pushNamed('/monitoring/geo'),
                    ),
                    _NavCard(
                      title: 'إحصائيات المنصة',
                      subtitle: 'إجمالي العقارات والسيارات، مشاهدات فيديو اليوم، ومخططات أيام/أسابيع/شهور',
                      icon: Icons.dashboard_customize_rounded,
                      onTap: () => Navigator.of(context).pushNamed('/monitoring/platform'),
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

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width.clamp(200, 400),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ColorUtils.withOpacity(AppColors.primary, 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorUtils.withOpacity(tint, 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tint, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: tint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.withOpacity(AppColors.primary, 0.2)),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
