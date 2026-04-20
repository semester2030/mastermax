import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../src/features/auth/models/user_type.dart';
import '../../src/features/auth/providers/auth_state.dart';
import '../../src/core/theme/app_colors.dart';
import '../../src/features/auth/screens/login_screen.dart';

/// يسمح بالدخول فقط لحسابات معرض السيارات (carDealer) وتاجر السيارات (carTrader).
class CarWebGuard extends StatelessWidget {
  final Widget child;

  const CarWebGuard({super.key, required this.child});

  static bool _isCarBusiness(UserType? t) =>
      t == UserType.carDealer || t == UserType.carTrader;

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
        if (!authState.isAuthenticated) {
          return const LoginScreen();
        }
        final type = authState.user?.type ?? authState.userType;
        if (!_isCarBusiness(type)) {
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car_outlined,
                        size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    const Text(
                      'هذا الموقع مخصص لمعارض السيارات وتجار السيارات',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'نوع حسابك الحالي لا يتطابق. استخدم حساب معرض أو تاجر سيارات، أو سجّل الدخول إلى ويب العقارات.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () async {
                        await authState.logout();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed('/');
                        }
                      },
                      child: const Text('تسجيل الخروج'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
