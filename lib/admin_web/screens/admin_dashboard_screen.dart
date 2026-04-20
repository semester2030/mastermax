import 'package:flutter/material.dart';
import '../../src/core/theme/app_colors.dart';
import '../services/admin_verification_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminVerificationService _verificationService = AdminVerificationService();
  int _pendingCount = 0;
  bool _loading = true;
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
      final list = await _verificationService.getPendingRequests();
      if (mounted) {
        setState(() {
          _pendingCount = list.length;
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
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'نظرة عامة',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _DashboardCard(
                        icon: Icons.verified_user,
                        title: 'طلبات التحقق المعلقة',
                        value: '$_pendingCount',
                        color: AppColors.primary,
                        onTap: () => Navigator.of(context).pushReplacementNamed('/verification'),
                      ),
                      _DashboardCard(
                        icon: Icons.people,
                        title: 'المستخدمون',
                        value: '—',
                        color: AppColors.textSecondary,
                        onTap: () => Navigator.of(context).pushReplacementNamed('/users'),
                      ),
                      _DashboardCard(
                        icon: Icons.security,
                        title: 'سجل الأمان',
                        value: '—',
                        color: AppColors.success,
                        onTap: () => Navigator.of(context).pushReplacementNamed('/security/logs'),
                      ),
                      _DashboardCard(
                        icon: Icons.fact_check_rounded,
                        title: 'سجل إجراءات الإدارة',
                        value: '—',
                        color: AppColors.primaryDark,
                        onTap: () => Navigator.of(context).pushReplacementNamed('/security/admin-audit'),
                      ),
                      _DashboardCard(
                        icon: Icons.video_library,
                        title: 'الفيديوهات',
                        value: '—',
                        color: AppColors.textPrimary,
                        onTap: () => Navigator.of(context).pushReplacementNamed('/content/videos'),
                      ),
                      _DashboardCard(
                        icon: Icons.insights_rounded,
                        title: 'مركز المراقبة',
                        value: '—',
                        color: AppColors.primaryDark,
                        onTap: () => Navigator.of(context).pushReplacementNamed('/monitoring'),
                      ),
                      _DashboardCard(
                        icon: Icons.map_rounded,
                        title: 'التحليل الجغرافي',
                        value: '—',
                        color: AppColors.primary,
                        onTap: () => Navigator.of(context).pushReplacementNamed('/monitoring/geo'),
                      ),
                      _DashboardCard(
                        icon: Icons.dashboard_customize_rounded,
                        title: 'إحصائيات المنصة',
                        value: '—',
                        color: AppColors.success,
                        onTap: () => Navigator.of(context).pushReplacementNamed('/monitoring/platform'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'روابط سريعة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            leading: const Icon(Icons.verified_user, color: AppColors.primary),
                            title: const Text('طلبات التحقق'),
                            onTap: () => Navigator.of(context).pushReplacementNamed('/verification'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.history, color: AppColors.primary),
                            title: const Text('سجل التحقق'),
                            onTap: () => Navigator.of(context).pushReplacementNamed('/verification/history'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.people, color: AppColors.primary),
                            title: const Text('قائمة المستخدمين'),
                            onTap: () => Navigator.of(context).pushReplacementNamed('/users'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.report, color: AppColors.primary),
                            title: const Text('البلاغات'),
                            onTap: () => Navigator.of(context).pushReplacementNamed('/reports'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.analytics_outlined, color: AppColors.primary),
                            title: const Text('مركز المراقبة والتحليلات'),
                            onTap: () => Navigator.of(context).pushReplacementNamed('/monitoring'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.fact_check_rounded, color: AppColors.primary),
                            title: const Text('سجل إجراءات الإدارة (تدقيق)'),
                            onTap: () => Navigator.of(context).pushReplacementNamed('/security/admin-audit'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.map_rounded, color: AppColors.primary),
                            title: const Text('التحليل الجغرافي (مدن وأحياء)'),
                            onTap: () => Navigator.of(context).pushReplacementNamed('/monitoring/geo'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.dashboard_customize_rounded, color: AppColors.primary),
                            title: const Text('إحصائيات المنصة والمشاهدات'),
                            onTap: () => Navigator.of(context).pushReplacementNamed('/monitoring/platform'),
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
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
