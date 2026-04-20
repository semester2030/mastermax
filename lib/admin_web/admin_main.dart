import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../firebase_options.dart';
import '../src/features/auth/providers/auth_state.dart';
import '../src/features/auth/services/auth_service.dart';
import 'services/admin_verification_service.dart';
import 'admin_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService(), lazy: false),
        ChangeNotifierProvider(create: (_) => AuthState()),
        Provider<AdminVerificationService>(create: (_) => AdminVerificationService()),
      ],
      child: const AdminApp(),
    ),
  );
}
