import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../src/features/auth/providers/auth_state.dart';
import '../../src/core/theme/app_colors.dart';

class AdminHeader extends StatelessWidget {
  final String title;

  const AdminHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight,
            blurRadius: 2,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Consumer<AuthState>(
            builder: (context, authState, _) {
              final email = authState.user?.email ?? '—';
              return Row(
                children: [
                  Icon(Icons.person, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    email,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () async {
                      await authState.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/');
                      }
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('خروج'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
