import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/color_utils.dart';
import '../dialogs/detailed_stats_dialog.dart';

/// Widget لعرض بطاقة إحصائية واحدة
///
/// يعرض قيمة إحصائية مع أيقونة ولون
/// يتبع الثيم الموحد للتطبيق
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String tooltip;
  final NumberFormat numberFormat;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.numberFormat,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.primaryContainer,
              width: 1,
            ),
          ),
          child: Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => DetailedStatsDialog.show(
                context,
                title: title,
                value: value,
                description: tooltip,
              ),
              borderRadius: BorderRadius.circular(16),
              splashColor: ColorUtils.withOpacity(AppColors.primary, 0.08),
              highlightColor: ColorUtils.withOpacity(AppColors.primary, 0.06),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      value,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
