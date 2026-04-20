import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../src/features/auth/screens/login_screen.dart';
import '../src/features/auth/models/user_type.dart';
import '../src/features/auth/providers/auth_state.dart';
import '../src/core/theme/app_colors.dart';
import '../src/features/profile/screens/car_showroom/vehicles_and_sales_management_screen.dart';
import '../src/features/cars/screens/add_car_screen.dart';
import '../src/features/cars/screens/edit_car_screen.dart';
import '../src/features/cars/screens/car_details_screen.dart';
import '../src/features/cars/models/car_model.dart';
import '../src/features/team/screens/team_management_screen.dart';
import '../src/features/profile/screens/business_analytics_screen.dart';
import '../src/features/premium_ads/screens/premium_ads_screen.dart';
import '../src/features/customer_service/screens/customer_service_screen.dart';
import '../src/features/chat/screens/chat_screen.dart';
import '../src/features/legal/screens/legal_home_screen.dart';
import '../src/features/favorites/screens/favorites_screen.dart';
import '../src/features/profile/widgets/coming_soon_feature.dart';
import 'car_web_layout.dart';
import 'car_web_dashboard_screen.dart';
import 'widgets/car_web_guard.dart';

class CarWebRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const CarWebLoginWrapper(),
        );

      case '/login':
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

      case '/dashboard':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'لوحة التحكم',
              child: const CarWebDashboardScreen(),
            ),
          ),
        );

      case '/vehicles-crm':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'المركبات والمبيعات',
              child: const VehiclesAndSalesManagementScreen(),
            ),
          ),
        );

      case '/add-car':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'إضافة سيارة',
              child: const AddCarScreen(),
            ),
          ),
        );

      /// نفس شاشة الإضافة — القائمة المشتركة تستدعي `/cars/add` (موبايل).
      case '/cars/add':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'إضافة سيارة',
              child: const AddCarScreen(),
            ),
          ),
        );

      case '/cars/edit':
        if (settings.arguments is! CarModel) {
          throw ArgumentError('تعديل المركبة يتطلب تمرير CarModel في arguments');
        }
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'تعديل السيارة',
              child: EditCarScreen(car: settings.arguments as CarModel),
            ),
          ),
        );

      /// تفاصيل السيارة — تُستدعى من `vehicles_tab` بـ `arguments: car.id`.
      case '/car-details':
        if (settings.arguments is! String) {
          throw ArgumentError('معرّف السيارة مطلوب لمسار /car-details');
        }
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'تفاصيل السيارة',
              child: CarDetailsScreen(carId: settings.arguments as String),
            ),
          ),
        );

      case '/team-management':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'إدارة الفريق',
              child: const TeamManagementScreen(),
            ),
          ),
        );

      case '/analytics':
        if (settings.arguments is! String) {
          throw ArgumentError('معرّف النشاط التجاري مطلوب للتقارير');
        }
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'التقارير والإحصائيات',
              child: BusinessAnalyticsScreen(
                businessId: settings.arguments as String,
              ),
            ),
          ),
        );

      case '/after-sales':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'خدمة ما بعد البيع',
              child: const ComingSoonFeatureBody(
                featureTitle: 'خدمة ما بعد البيع',
              ),
            ),
          ),
        );

      case '/warranty-maintenance':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'الضمان والصيانة',
              child: const ComingSoonFeatureBody(
                featureTitle: 'الضمان والصيانة',
              ),
            ),
          ),
        );

      case '/special-offers':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'العروض الخاصة',
              child: const ComingSoonFeatureBody(
                featureTitle: 'العروض الخاصة',
              ),
            ),
          ),
        );

      case '/financing':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'التمويل والتقسيط',
              child: const ComingSoonFeatureBody(
                featureTitle: 'التمويل والتقسيط',
              ),
            ),
          ),
        );

      case '/premium-ads':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'الإعلانات المميزة',
              child: const PremiumAdsScreen(),
            ),
          ),
        );

      case '/customer-service':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'خدمة العملاء',
              child: const CustomerServiceScreen(),
            ),
          ),
        );

      case '/chat':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'المحادثات',
              child: const ChatScreen(),
            ),
          ),
        );

      case '/favorites':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'المفضلة',
              child: const FavoritesScreen(),
            ),
          ),
        );

      case '/legal':
        return MaterialPageRoute(
          builder: (_) => CarWebGuard(
            child: CarWebLayout(
              title: 'السياسات والشروط',
              child: const LegalHomeScreen(),
            ),
          ),
        );

      case '/wrong-account':
        return MaterialPageRoute(
          builder: (_) => const _CarWebWrongAccountScreen(),
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

class CarWebLoginWrapper extends StatelessWidget {
  const CarWebLoginWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        if (!authState.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.read<AuthState>().initialize();
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (authState.isAuthenticated) {
          final type = authState.user?.type ?? authState.userType;
          final ok = type == UserType.carDealer || type == UserType.carTrader;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (ok) {
              Navigator.of(context).pushReplacementNamed('/dashboard');
            } else {
              Navigator.of(context).pushReplacementNamed('/wrong-account');
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const LoginScreen();
      },
    );
  }
}

class _CarWebWrongAccountScreen extends StatelessWidget {
  const _CarWebWrongAccountScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 56, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text(
                  'هذا الموقع لمعارض السيارات وتجار السيارات فقط',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'سجّل الدخول بحساب معرض أو تاجر سيارات، أو استخدم ويب إدارة العقارات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await context.read<AuthState>().logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/');
                    }
                  },
                  child: const Text('تسجيل الخروج والعودة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
