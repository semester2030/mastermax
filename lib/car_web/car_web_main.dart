import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import '../firebase_options.dart';
import '../src/features/auth/providers/auth_state.dart';
import '../src/features/auth/services/auth_service.dart';
import '../src/features/cars/providers/car_provider.dart';
import '../src/features/cars/services/car_service.dart';
import '../src/features/favorites/providers/favorites_provider.dart';
import '../src/features/chat/providers/chat_provider.dart';
import '../src/features/profile/providers/business_analytics_provider.dart';
import '../src/features/profile/providers/car_showroom/customers_provider.dart';
import '../src/features/profile/providers/car_showroom/sales_provider.dart';
import '../src/features/profile/services/car_showroom/customers_service.dart';
import '../src/features/profile/services/car_showroom/sales_service.dart';
import '../src/features/customer_service/providers/customer_service_provider.dart';
import '../src/features/customer_service/providers/live_chat_provider.dart';
import '../src/features/team/services/team_service.dart';
import '../src/core/utils/logger.dart';
import 'car_web_app.dart';

const String companyId =
    String.fromEnvironment('COMPANY_ID', defaultValue: 'DEFAULT_COMPANY_ID');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  intl.Intl.defaultLocale = 'ar';

  try {
    logInfo('🚗 Starting Car CRM Web...');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    logInfo('✅ Firebase initialized for Car Web');

    final authService = AuthService();
    final carService = CarService();
    final teamService = TeamService(companyId: companyId);
    final customersService = CustomersService();
    final salesService = SalesService();

    runApp(
      MultiProvider(
        providers: [
          Provider<AuthService>(
            create: (_) => authService,
            lazy: false,
          ),
          ChangeNotifierProvider(create: (_) => AuthState()),
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
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => BusinessAnalyticsProvider()),
          ChangeNotifierProvider(create: (_) => CustomerServiceProvider()),
          ChangeNotifierProvider(create: (_) => LiveChatProvider()),
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
        ],
        child: const CarCrmWebApp(),
      ),
    );
  } catch (e, stackTrace) {
    logError('❌ Car Web init failed', e, stackTrace);
    runApp(
      MaterialApp(
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
        home: const Scaffold(
          body: Center(
            child: Text(
              'عذراً، حدث خطأ أثناء تشغيل الموقع. الرجاء المحاولة مرة أخرى.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
