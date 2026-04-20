import 'package:flutter/material.dart';
import '../../../../src/core/theme/app_colors.dart';
import '../../../../src/features/auth/models/user_type.dart';

class UserRow extends StatelessWidget {
  final String userId;
  final String email;
  final UserType type;
  final bool isVerified;
  final DateTime? createdAt;
  final VoidCallback onTap;

  const UserRow({
    super.key,
    required this.userId,
    required this.email,
    required this.type,
    required this.isVerified,
    this.createdAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Text(
            email.isNotEmpty ? email.substring(0, 1).toUpperCase() : '?',
            style: const TextStyle(color: AppColors.primary),
          ),
        ),
        title: Text(
          email,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          '${type.arabicName} • ${isVerified ? "موثق" : "غير موثق"}${createdAt != null ? " • ${_formatDate(createdAt!)}" : ""}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_left),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
