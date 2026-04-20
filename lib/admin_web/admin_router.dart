import 'package:flutter/material.dart';
import 'admin_layout.dart';
import 'widgets/admin_guard.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/verification/verification_pending_screen.dart';
import 'screens/verification/verification_history_screen.dart';
import 'screens/users/users_list_screen.dart';
import 'screens/users/user_detail_screen.dart';
import 'screens/security/security_logs_screen.dart';
import 'screens/security/admin_audit_log_screen.dart';
import 'screens/security/failed_logins_screen.dart';
import 'screens/content/videos_management_screen.dart';
import 'screens/content/orphaned_videos_screen.dart';
import 'screens/reports/user_reports_screen.dart';
import 'screens/settings/app_settings_screen.dart';
import 'screens/settings/admin_accounts_screen.dart';
import 'screens/monitoring/monitoring_hub_screen.dart';
import 'screens/monitoring/monitoring_video_engagement_screen.dart';
import 'screens/monitoring/monitoring_media_failures_screen.dart';
import 'screens/monitoring/monitoring_seller_rollups_screen.dart';
import 'screens/monitoring/monitoring_sessions_screen.dart';
import 'screens/monitoring/geo_analytics_screen.dart';
import 'screens/monitoring/platform_analytics_screen.dart';

class AdminRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const AdminLoginScreen());

      case '/dashboard':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'لوحة التحكم',
              currentRoute: '/dashboard',
              child: const AdminDashboardScreen(),
            ),
          ),
        );

      case '/verification':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'طلبات التحقق',
              currentRoute: '/verification',
              child: const VerificationPendingScreen(),
            ),
          ),
        );

      case '/verification/history':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'سجل التحقق',
              currentRoute: '/verification/history',
              child: const VerificationHistoryScreen(),
            ),
          ),
        );

      case '/users':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'المستخدمون',
              currentRoute: '/users',
              child: const UsersListScreen(),
            ),
          ),
        );

      case '/users/detail':
        final userId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'تفاصيل المستخدم',
              currentRoute: '/users/detail',
              child: UserDetailScreen(userId: userId ?? ''),
            ),
          ),
        );

      case '/security/logs':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'سجل الأمان',
              currentRoute: '/security/logs',
              child: const SecurityLogsScreen(),
            ),
          ),
        );

      case '/security/failed-logins':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'محاولات الدخول الفاشلة',
              currentRoute: '/security/failed-logins',
              child: const FailedLoginsScreen(),
            ),
          ),
        );

      case '/security/admin-audit':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'سجل إجراءات الإدارة',
              currentRoute: '/security/admin-audit',
              child: const AdminAuditLogScreen(),
            ),
          ),
        );

      case '/content/videos':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'إدارة الفيديوهات',
              currentRoute: '/content/videos',
              child: const VideosManagementScreen(),
            ),
          ),
        );

      case '/content/orphaned':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'فيديوهات يتيمة',
              currentRoute: '/content/orphaned',
              child: const OrphanedVideosScreen(),
            ),
          ),
        );

      case '/monitoring':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'مركز المراقبة',
              currentRoute: '/monitoring',
              child: const MonitoringHubScreen(),
            ),
          ),
        );

      case '/monitoring/videos':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'مشاهدات الفيديو',
              currentRoute: '/monitoring/videos',
              child: const MonitoringVideoEngagementScreen(),
            ),
          ),
        );

      case '/monitoring/failures':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'فشل رفع الوسائط',
              currentRoute: '/monitoring/failures',
              child: const MonitoringMediaFailuresScreen(),
            ),
          ),
        );

      case '/monitoring/sellers':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'الشركات والبائعون',
              currentRoute: '/monitoring/sellers',
              child: const MonitoringSellerRollupsScreen(),
            ),
          ),
        );

      case '/monitoring/sessions':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'جلسات المستخدم',
              currentRoute: '/monitoring/sessions',
              child: const MonitoringSessionsScreen(),
            ),
          ),
        );

      case '/monitoring/geo':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'التحليل الجغرافي',
              currentRoute: '/monitoring/geo',
              child: const GeoAnalyticsScreen(),
            ),
          ),
        );

      case '/monitoring/platform':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'إحصائيات المنصة',
              currentRoute: '/monitoring/platform',
              child: const PlatformAnalyticsScreen(),
            ),
          ),
        );

      case '/reports':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'البلاغات',
              currentRoute: '/reports',
              child: const UserReportsScreen(),
            ),
          ),
        );

      case '/settings':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'إعدادات التطبيق',
              currentRoute: '/settings',
              child: const AppSettingsScreen(),
            ),
          ),
        );

      case '/settings/admins':
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'حسابات الأدمن',
              currentRoute: '/settings/admins',
              child: const AdminAccountsScreen(),
            ),
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => AdminGuard(
            child: AdminLayout(
              title: 'لوحة التحكم',
              currentRoute: '/dashboard',
              child: const AdminDashboardScreen(),
            ),
          ),
        );
    }
  }
}
