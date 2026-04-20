import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart' as intl;
import '../firebase_options.dart';
import '../src/features/auth/providers/auth_state.dart';
import '../src/features/auth/services/auth_service.dart';
import '../src/features/profile/providers/real_estate/real_estate_customers_provider.dart';
import '../src/features/profile/providers/real_estate/branches_provider.dart';
import '../src/features/profile/providers/real_estate/rental_provider.dart';
import '../src/features/profile/providers/real_estate/rental_payment_provider.dart';
import '../src/features/profile/services/real_estate/real_estate_customers_service.dart';
import '../src/features/profile/services/real_estate/branches_service.dart';
import '../src/features/profile/services/real_estate/rental_service.dart';
import '../src/features/profile/services/real_estate/rental_payment_service.dart';
import '../src/features/profile/screens/real_estate/viewmodels/sales_management_viewmodel.dart';
import '../src/features/profile/providers/business_analytics_provider.dart';
import '../src/features/properties/providers/property_provider.dart';
import '../src/features/properties/services/property_service.dart';
import '../src/core/theme/app_theme.dart';
import '../src/core/utils/logger.dart';
import '../src/core/constants/app_brand.dart';
import 'web_router.dart';

/// نقطة الدخول لتطبيق الويب - CRM فقط
/// يمكن استدعاؤها من main.dart أو بشكل منفصل
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة اللغة العربية
  intl.Intl.defaultLocale = 'ar';

  try {
    logInfo('🌐 Starting Web CRM Application...');

    // ✅ تهيئة WebView للويب
    // WebView يتم تهيئته تلقائياً عند استيراد webview_flutter_web
    if (kIsWeb) {
      logInfo('✅ WebView will be initialized automatically for Web');
    }

    // تهيئة Firebase للويب
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.web,
    );
    logInfo('✅ Firebase initialized for Web');

    // تهيئة الخدمات
    final authService = AuthService();
    final realEstateCustomersService = RealEstateCustomersService();
    final branchesService = BranchesService();
    final rentalService = RentalService();
    final rentalPaymentService = RentalPaymentService();
    final propertyService = PropertyService();

    logInfo('✅ Services initialized');

    runApp(
      MultiProvider(
        providers: [
          // Auth
          Provider<AuthService>(
            create: (_) => authService,
            lazy: false,
          ),
          ChangeNotifierProvider(create: (_) => AuthState()),

          // Real Estate CRM Providers
          Provider<RealEstateCustomersService>(
            create: (_) => realEstateCustomersService,
            lazy: true,
          ),
          Provider<BranchesService>(
            create: (_) => branchesService,
            lazy: true,
          ),
          Provider<RentalService>(
            create: (_) => rentalService,
            lazy: true,
          ),
          Provider<RentalPaymentService>(
            create: (_) => rentalPaymentService,
            lazy: true,
          ),
          Provider<PropertyService>(
            create: (_) => propertyService,
            lazy: true,
          ),
          ChangeNotifierProvider(
            create: (_) => PropertyProvider(propertyService),
          ),
          ChangeNotifierProxyProvider<AuthState, RealEstateCustomersProvider>(
            create: (context) => RealEstateCustomersProvider(
              realEstateCustomersService,
              context.read<AuthState>(),
            ),
            update: (context, authState, previous) =>
                RealEstateCustomersProvider(
              realEstateCustomersService,
              authState,
            ),
          ),
          ChangeNotifierProxyProvider<AuthState, BranchesProvider>(
            create: (context) => BranchesProvider(
              branchesService,
              context.read<AuthState>(),
            ),
            update: (context, authState, previous) => BranchesProvider(
              branchesService,
              authState,
            ),
          ),
          ChangeNotifierProxyProvider<AuthState, RentalProvider>(
            create: (context) => RentalProvider(
              rentalService,
              context.read<AuthState>(),
            ),
            update: (context, authState, previous) => RentalProvider(
              rentalService,
              authState,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => RentalPaymentProvider(rentalPaymentService),
          ),
          
          // Sales Management ViewModel (للـ Dashboard)
          ChangeNotifierProvider(
            create: (_) => SalesManagementViewModel(),
          ),
          
          // Business Analytics Provider (للـ Analytics Screen)
          ChangeNotifierProvider(
            create: (_) => BusinessAnalyticsProvider(),
          ),
        ],
        child: const WebCrmApp(),
      ),
    );
  } catch (e, stackTrace) {
    logError('❌ Critical error during Web initialization', e, stackTrace);
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'عذراً، حدث خطأ أثناء تشغيل التطبيق. الرجاء المحاولة مرة أخرى.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

/// تطبيق الويب - CRM
class WebCrmApp extends StatelessWidget {
  const WebCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppBrand.displayName} CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ar', 'SA'),
      onGenerateRoute: WebRouter.onGenerateRoute,
      initialRoute: '/',
    );
  }
}
