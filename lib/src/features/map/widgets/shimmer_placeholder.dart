import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';

/// Widget للـ Shimmer effect (تأثير التحميل)
///
/// يستخدم لعرض تأثير shimmer أثناء تحميل الصور
/// يتبع الثيم الموحد للتطبيق
class ShimmerPlaceholder extends StatelessWidget {
  final Widget child;

  const ShimmerPlaceholder({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.primaryLight,
      highlightColor: AppColors.background,
      child: child,
    );
  }
}
