import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'firebase_options.dart';
import 'src/navigation/app_router.dart';
import 'src/features/map/providers/map_state.dart';
import 'src/features/auth/providers/auth_state.dart';
import 'src/features/cars/providers/car_provider.dart';
import 'src/features/cars/services/car_service.dart';
import 'src/features/spotlight/providers/video_provider.dart';
import 'src/features/settings/providers/app_user_settings_provider.dart';
import 'src/features/spotlight/services/video_service.dart';
import 'src/features/favorites/providers/favorites_provider.dart';
import 'src/features/chat/providers/chat_provider.dart';
import 'src/features/profile/providers/user_features_provider.dart';
import 'src/features/profile/providers/business_analytics_provider.dart';
import 'src/features/profile/providers/car_showroom/customers_provider.dart';
import 'src/features/profile/providers/car_showroom/sales_provider.dart';
import 'src/features/profile/services/car_showroom/customers_service.dart';
import 'src/features/profile/services/car_showroom/sales_service.dart';
import 'src/features/profile/providers/real_estate/real_estate_customers_provider.dart';
import 'src/features/profile/providers/real_estate/branches_provider.dart';
import 'src/features/profile/providers/real_estate/rental_provider.dart';
import 'src/features/profile/providers/real_estate/rental_payment_provider.dart';
import 'src/features/profile/services/real_estate/real_estate_customers_service.dart';
import 'src/features/profile/services/real_estate/branches_service.dart';
import 'src/features/profile/services/real_estate/rental_service.dart';
import 'src/features/profile/services/real_estate/rental_payment_service.dart';
import 'src/features/customer_service/providers/customer_service_provider.dart';
import 'src/features/customer_service/providers/live_chat_provider.dart';
import 'src/features/properties/services/property_service.dart';
import 'src/features/properties/providers/property_provider.dart';
import 'src/core/theme/dark_theme.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/team/services/team_service.dart';
import 'src/features/real_estate_cars/providers/real_estate_cars_provider.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'src/core/utils/logger.dart';
import 'src/core/constants/app_brand.dart';
import 'src/core/session/session_telemetry_host.dart';
import 'src/core/services/remote_config_service.dart';
import 'src/features/map/services/location_service.dart';
import 'src/features/map/services/clustering_service.dart';
import 'package:flutter/foundation.dart';
import 'src/features/map/services/map_service.dart';
import 'src/features/auth/services/auth_service.dart';
import 'src/features/spotlight/config/video_upload_config.dart';
import 'src/features/images/config/image_upload_config.dart';

// App Constants
const String companyId = String.fromEnvironment('COMPANY_ID', defaultValue: 'DEFAULT_COMPANY_ID');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة إعدادات اللغة العربية
  intl.Intl.defaultLocale = 'ar';
  
  late final MapService mapService;
  
  try {
    logInfo('Starting application initialization...');
    
    // تهيئة Google Maps
    mapService = MapService();
    if (!kIsWeb) {
      await mapService.initialize();
      logInfo('Google Maps initialized successfully');
    }
    
    // تهيئة Firebase بناءً على المنصة
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.web,
      );
      
      // تهيئة خاصة للويب
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
      };
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    logInfo('Firebase initialized successfully');

    await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
    logInfo('Firebase Performance Monitoring enabled');

    // تهيئة Remote Config
    await RemoteConfigService().initialize();
    logInfo('Remote Config initialized successfully');

    // Cloudflare Stream / Images: الأسرار على Cloud Functions فقط — انظر `functions/index.js`.
    try {
      await VideoUploadConfig.clearLegacyCloudflareSecretsFromPrefs();
      await ImageUploadConfig.clearLegacyCloudflareSecretsFromPrefs();
      await VideoUploadConfig.setUseCloudflare(true);
      await ImageUploadConfig.setUseCloudflare(true);
      logInfo('✅ Cloudflare upload flags enabled (Stream + Images via Firebase Functions)');
    } catch (e) {
      logError('⚠️ Failed to set Cloudflare feature flags', e, null);
    }

  } catch (e, stackTrace) {
    logError('Critical error during initialization', e, stackTrace);
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'عذراً، حدث خطأ أثناء تشغيل التطبيق. الرجاء المحاولة مرة أخرى.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    ));
    return;
  }

  // تهيئة الخدمات
  final authService = AuthService();
  final carService = CarService();
  final videoService = VideoService();
  final teamService = TeamService(companyId: companyId);
  final propertyService = PropertyService();
  final customersService = CustomersService();
  final salesService = SalesService();
  final realEstateCustomersService = RealEstateCustomersService();
  final branchesService = BranchesService();
  final rentalService = RentalService();
  final rentalPaymentService = RentalPaymentService();

  // تسجيل بدء تشغيل الخدمات
  logInfo('Services created successfully');

  runApp(
    MultiProvider(
      providers: [
        // Core Providers
        Provider<AuthService>(
          create: (_) => authService,
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(
          create: (context) => MapState(
            LocationService(),
            ClusteringService(),
          ),
        ),

        // Property Providers
        Provider<PropertyService>(
          create: (_) => propertyService,
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => PropertyProvider(
            propertyService,
          ),
        ),

        // Car Related Providers
        Provider<CarService>(
          create: (_) => carService,
          lazy: true,
        ),
        ChangeNotifierProxyProvider<AuthState, CarProvider>(
          create: (context) => CarProvider(
            carService,
            context.read<AuthState>(),
          ),
          update: (context, authState, previous) => CarProvider(
            carService,
            authState,
          )..loadCars(),
        ),
        
        // Other Feature Providers
        ChangeNotifierProvider(
          create: (_) => VideoProvider(videoService),
        ),
        ChangeNotifierProvider(create: (_) => AppUserSettingsProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserFeaturesProvider()),
        ChangeNotifierProvider(create: (_) => BusinessAnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => CustomerServiceProvider()),
        ChangeNotifierProvider(create: (_) => LiveChatProvider()),
        
        // Car Showroom CRM Providers
        Provider<CustomersService>(
          create: (_) => customersService,
          lazy: true,
        ),
        Provider<SalesService>(
          create: (_) => salesService,
          lazy: true,
        ),
        ChangeNotifierProxyProvider<AuthState, CustomersProvider>(
          create: (context) => CustomersProvider(
            customersService,
            context.read<AuthState>(),
          ),
          update: (context, authState, previous) => CustomersProvider(
            customersService,
            authState,
          ),
        ),
        ChangeNotifierProxyProvider<AuthState, SalesProvider>(
          create: (context) => SalesProvider(
            salesService,
            context.read<AuthState>(),
          ),
          update: (context, authState, previous) => SalesProvider(
            salesService,
            authState,
          ),
        ),
        Provider<TeamService>(create: (_) => teamService),
        
        // Real Estate CRM Providers
        Provider<RealEstateCustomersService>(
          create: (_) => realEstateCustomersService,
          lazy: true,
        ),
        Provider<BranchesService>(
          create: (_) => branchesService,
          lazy: true,
        ),
        ChangeNotifierProxyProvider<AuthState, RealEstateCustomersProvider>(
          create: (context) => RealEstateCustomersProvider(
            realEstateCustomersService,
            context.read<AuthState>(),
          ),
          update: (context, authState, previous) => RealEstateCustomersProvider(
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
        
        // Rental Providers
        Provider<RentalService>(
          create: (_) => rentalService,
          lazy: true,
        ),
        Provider<RentalPaymentService>(
          create: (_) => rentalPaymentService,
          lazy: true,
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
        
        // UI State Providers
        ChangeNotifierProvider(create: (_) => RealEstateAndCarsProvider()),
        Provider<MapService>(
          create: (_) => mapService,
          dispose: (_, service) => service.dispose(),
          lazy: false,
        ),
      ],
      child: SessionTelemetryHost(
        child: MaterialApp(
          title: AppBrand.displayName,
          theme: AppTheme.lightTheme,
          darkTheme: DarkTheme.theme,
          // الوضع الداكن للنظام (أندرويد) يطبّق darkTheme بينما كثير من الشاشات
          // تستخدم ألواناً ثابتة فاتحة — فيظهر خلط فاتح/داكن. نُثبت الفاتح حتى يُدعم الداكن بالكامل.
          themeMode: ThemeMode.light,
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          onGenerateRoute: AppRouter.onGenerateRoute,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ar', ''),
          ],
          locale: const Locale('ar', ''),
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox(),
            );
          },
        ),
      ),
    ),
  );
}
