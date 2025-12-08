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
import 'src/features/spotlight/services/video_service.dart';
import 'src/features/favorites/providers/favorites_provider.dart';
import 'src/features/chat/providers/chat_provider.dart';
import 'src/features/profile/providers/user_features_provider.dart';
import 'src/features/profile/providers/business_analytics_provider.dart';
import 'src/features/customer_service/providers/customer_service_provider.dart';
import 'src/features/customer_service/providers/live_chat_provider.dart';
import 'src/features/properties/services/property_service.dart';
import 'src/features/properties/providers/property_provider.dart';
import 'src/core/theme/dark_theme.dart';
import 'src/features/team/services/team_service.dart';
import 'src/features/real_estate_cars/providers/real_estate_cars_provider.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'src/core/utils/logger.dart';
import 'src/core/services/remote_config_service.dart';
import 'src/features/map/services/location_service.dart';
import 'src/features/map/services/clustering_service.dart';
import 'package:flutter/foundation.dart';
import 'src/features/map/services/map_service.dart';

// App Constants
const String companyId = String.fromEnvironment('COMPANY_ID', defaultValue: 'DEFAULT_COMPANY_ID');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة إعدادات اللغة العربية
  intl.Intl.defaultLocale = 'ar';
  
  late final MapService mapService;
  
  try {
    logInfo('Starting application initialization...');
    
    // تهيئة Mapbox
    mapService = MapService();
    if (!kIsWeb) {
      await mapService.initialize();
      logInfo('Mapbox initialized successfully');
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
  final carService = CarService();
  final videoService = VideoService();
  final teamService = TeamService(companyId: companyId);
  final propertyService = PropertyService();

  // تسجيل بدء تشغيل الخدمات
  logInfo('Services created successfully');

  runApp(
    MultiProvider(
      providers: [
        // Core Providers
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
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserFeaturesProvider()),
        ChangeNotifierProvider(create: (_) => BusinessAnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => CustomerServiceProvider()),
        ChangeNotifierProvider(create: (_) => LiveChatProvider()),
        Provider<TeamService>(create: (_) => teamService),
        
        // UI State Providers
        ChangeNotifierProvider(create: (_) => RealEstateAndCarsProvider()),
        Provider<MapService>(
          create: (_) => mapService,
          dispose: (_, service) => service.dispose(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'MasterMax 2030',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          primaryColor: const Color(0xFF1E3A8A),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1E3A8A),      // Royal Blue
            secondary: Color(0xFF455A64),     // Metallic Grey
            surface: Color(0xFFFFFFFF),    // Very light white
            error: Color(0xFFEF4444),         // Red
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Color(0xFF0F172A),  // Shiny black
            onError: Colors.white,
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(color: Color(0xFF0F172A)),
            headlineMedium: TextStyle(color: Color(0xFF0F172A)),
            headlineSmall: TextStyle(color: Color(0xFF0F172A)),
            titleLarge: TextStyle(color: Color(0xFF0F172A)),
            titleMedium: TextStyle(color: Color(0xFF475569)),
            titleSmall: TextStyle(color: Color(0xFF475569)),
            bodyLarge: TextStyle(color: Color(0xFF0F172A)),
            bodyMedium: TextStyle(color: Color(0xFF475569)),
            bodySmall: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
        darkTheme: DarkTheme.theme,
        themeMode: ThemeMode.system,
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
  );
}
