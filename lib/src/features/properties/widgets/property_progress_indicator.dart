import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

/// Widget لعرض نسبة إكمال النموذج
///
/// يعرض شريط تقدم ونسبة الإكمال
/// يتبع الثيم الموحد للتطبيق
class PropertyProgressIndicator extends StatelessWidget {
  final int completedFields;
  final int totalFields;

  const PropertyProgressIndicator({
    super.key,
    required this.completedFields,
    required this.totalFields,
  });

  double get progress => totalFields > 0 ? completedFields / totalFields : 0.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.primary, 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'نسبة الإكمال',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: progress >= 0.8 
                      ? AppColors.success 
                      : progress >= 0.5 
                          ? Colors.orange 
                          : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.primaryLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 0.8 
                    ? AppColors.success 
                    : progress >= 0.5 
                        ? Colors.orange 
                        : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$completedFields من $totalFields حقل مكتمل',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
