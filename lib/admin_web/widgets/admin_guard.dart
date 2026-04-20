import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../src/features/auth/providers/auth_state.dart';
import '../../src/core/theme/app_colors.dart';
import '../screens/admin_login_screen.dart';

/// يتحقق من أن المستخدم أدمن قبل عرض المحتوى
class AdminGuard extends StatelessWidget {
  final Widget child;

  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        if (!authState.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!authState.isAuthenticated) {
          return const AdminLoginScreen();
        }
        if (!authState.isAdmin) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'غير مصرح',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'هذه لوحة الإدارة. يجب أن يكون حسابك أدمن للدخول.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
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
          );
        }
        return child;
      },
    );
  }
}
