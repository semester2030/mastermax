import 'package:flutter/material.dart';
import '../../src/core/theme/app_colors.dart';

class AdminSidebar extends StatelessWidget {
  final String currentRoute;

  const AdminSidebar({super.key, required this.currentRoute});

  void _navigate(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight,
            blurRadius: 4,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: AppColors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'لوحة الإدارة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _MenuItem(
            icon: Icons.dashboard,
            label: 'لوحة التحكم',
            route: '/dashboard',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/dashboard'),
          ),
          _MenuItem(
            icon: Icons.verified_user,
            label: 'طلبات التحقق',
            route: '/verification',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/verification'),
          ),
          _MenuItem(
            icon: Icons.history,
            label: 'سجل التحقق',
            route: '/verification/history',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/verification/history'),
          ),
          _MenuItem(
            icon: Icons.people,
            label: 'المستخدمون',
            route: '/users',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/users'),
          ),
          _MenuItem(
            icon: Icons.security,
            label: 'سجل الأمان',
            route: '/security/logs',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/security/logs'),
          ),
          _MenuItem(
            icon: Icons.login,
            label: 'دخول فاشل',
            route: '/security/failed-logins',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/security/failed-logins'),
          ),
          _MenuItem(
            icon: Icons.fact_check_rounded,
            label: 'سجل إجراءات الإدارة',
            route: '/security/admin-audit',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/security/admin-audit'),
          ),
          _MenuItem(
            icon: Icons.video_library,
            label: 'الفيديوهات',
            route: '/content/videos',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/content/videos'),
          ),
          _MenuItem(
            icon: Icons.broken_image,
            label: 'فيديوهات يتيمة',
            route: '/content/orphaned',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/content/orphaned'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'المراقبة والتحليلات',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _MenuItem(
            icon: Icons.insights_rounded,
            label: 'مركز المراقبة',
            route: '/monitoring',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/monitoring'),
          ),
          _MenuItem(
            icon: Icons.trending_up_rounded,
            label: 'مشاهدات الفيديو',
            route: '/monitoring/videos',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/monitoring/videos'),
          ),
          _MenuItem(
            icon: Icons.apartment_rounded,
            label: 'الشركات والبائعون',
            route: '/monitoring/sellers',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/monitoring/sellers'),
          ),
          _MenuItem(
            icon: Icons.cloud_off_rounded,
            label: 'فشل رفع الوسائط',
            route: '/monitoring/failures',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/monitoring/failures'),
          ),
          _MenuItem(
            icon: Icons.timeline_rounded,
            label: 'جلسات المستخدم',
            route: '/monitoring/sessions',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/monitoring/sessions'),
          ),
          _MenuItem(
            icon: Icons.analytics_outlined,
            label: 'التحليل الجغرافي',
            route: '/monitoring/geo',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/monitoring/geo'),
          ),
          _MenuItem(
            icon: Icons.dashboard_customize_rounded,
            label: 'إحصائيات المنصة',
            route: '/monitoring/platform',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/monitoring/platform'),
          ),
          _MenuItem(
            icon: Icons.report,
            label: 'البلاغات',
            route: '/reports',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/reports'),
          ),
          _MenuItem(
            icon: Icons.settings,
            label: 'إعدادات التطبيق',
            route: '/settings',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/settings'),
          ),
          _MenuItem(
            icon: Icons.manage_accounts,
            label: 'حسابات الأدمن',
            route: '/settings/admins',
            currentRoute: currentRoute,
            onTap: () => _navigate(context, '/settings/admins'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentRoute == route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isActive ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? AppColors.primary : AppColors.textPrimary,
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
