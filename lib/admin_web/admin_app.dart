import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../src/core/theme/app_theme.dart';
import '../src/core/constants/app_brand.dart';
import 'admin_router.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'لوحة إدارة ${AppBrand.displayName}',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      onGenerateRoute: AdminRouter.onGenerateRoute,
    );
  }
}
