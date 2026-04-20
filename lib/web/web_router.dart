import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../src/features/auth/screens/login_screen.dart';
import '../src/features/auth/providers/auth_state.dart';
import '../src/features/profile/screens/real_estate/sales_management_screen.dart';
import '../src/features/profile/screens/real_estate/customers_management_screen.dart';
import '../src/features/profile/screens/real_estate/branches_management_screen.dart';
import '../src/features/profile/screens/real_estate/rentals/rentals_management_screen.dart';
import '../src/features/profile/screens/business_analytics_screen.dart';
import '../src/features/profile/screens/real_estate/rentals/add_rental_screen.dart';
import '../src/features/profile/screens/real_estate/rentals/rental_details_screen.dart';
import '../src/features/profile/screens/real_estate/rentals/rental_contract_viewer_screen.dart';
import '../src/features/properties/screens/property_management_screen.dart';
import 'web_dashboard_screen.dart';
import 'web_layout.dart';

/// Router خاص بتطبيق الويب - CRM
class WebRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const WebLoginWrapper(),
        );

      case '/login':
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

      case '/dashboard':
        return MaterialPageRoute(
          builder: (_) => const WebDashboardScreen(),
        );

      // === CRM Routes ===
      case '/sales-management':
        return MaterialPageRoute(
          builder: (_) => const WebLayout(
            title: 'إدارة المبيعات',
            child: RealEstateSalesManagementScreen(),
          ),
        );

      case '/properties-management':
        return MaterialPageRoute(
          builder: (_) => const WebLayout(
            title: 'إدارة العقارات',
            child: PropertyManagementScreen(),
          ),
        );

      case '/customers-management':
        return MaterialPageRoute(
          builder: (_) => const WebLayout(
            title: 'إدارة العملاء',
            child: CustomersManagementScreen(),
          ),
        );

      case '/rentals-management':
        return MaterialPageRoute(
          builder: (_) => const WebLayout(
            title: 'إدارة الإيجارات',
            child: RentalsManagementScreen(),
          ),
        );

      case '/rentals/add':
        return MaterialPageRoute(
          builder: (_) => const WebLayout(
            title: 'إضافة عقد إيجار',
            child: AddRentalScreen(),
          ),
        );

      case '/rentals/details':
        if (settings.arguments is! String) {
          throw ArgumentError('Required rental ID parameter is missing');
        }
        return MaterialPageRoute(
          builder: (_) => WebLayout(
            title: 'تفاصيل العقد',
            child: RentalDetailsScreen(
              rentalId: settings.arguments as String,
            ),
          ),
        );

      case '/rentals/contract':
        if (settings.arguments is! Map<String, dynamic>) {
          throw ArgumentError('Required parameters are missing');
        }
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => WebLayout(
            title: 'عرض العقد',
            child: RentalContractViewerScreen(
              contractUrl: args['contractUrl'] as String,
              rentalTitle: args['rentalTitle'] as String? ?? args['fileName'] as String? ?? 'عقد الإيجار',
              fileName: args['fileName'] as String?,
            ),
          ),
        );

      case '/branches-management':
        return MaterialPageRoute(
          builder: (_) => const WebLayout(
            title: 'إدارة الفروع',
            child: BranchesManagementScreen(),
          ),
        );

      case '/analytics':
        if (settings.arguments is! String) {
          throw ArgumentError('Required business ID parameter is missing');
        }
        return MaterialPageRoute(
          builder: (_) => WebLayout(
            title: 'التقارير والإحصائيات',
            child: BusinessAnalyticsScreen(
              businessId: settings.arguments as String,
            ),
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('الصفحة غير موجودة: ${settings.name}'),
            ),
          ),
        );
    }
  }
}

/// Wrapper لصفحة تسجيل الدخول - يتحقق من حالة المصادقة
class WebLoginWrapper extends StatelessWidget {
  const WebLoginWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        // إذا كان مسجل دخول، انتقل إلى Dashboard
        if (authState.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/dashboard');
          });
        }
        return const LoginScreen();
      },
    );
  }
}
