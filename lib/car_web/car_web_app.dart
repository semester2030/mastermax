import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../src/core/theme/app_theme.dart';
import '../src/core/constants/app_brand.dart';
import 'car_web_router.dart';

class CarCrmWebApp extends StatelessWidget {
  const CarCrmWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppBrand.displayName} — معارض السيارات',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      onGenerateRoute: CarWebRouter.onGenerateRoute,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
