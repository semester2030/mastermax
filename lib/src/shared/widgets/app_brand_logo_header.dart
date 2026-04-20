import 'dart:math' show min;

import 'package:flutter/material.dart';
import '../../core/constants/app_brand.dart';
import '../../core/theme/app_colors.dart';

/// شعار الهوية مع [AspectRatio] حسب ملف الشعار.
///
/// على الشاشات العريضة (ويب وسطح مكتب) يُقيَّد العرض الأقصى حتى لا يتضخم الشعار.
class AppBrandLogoHeader extends StatelessWidget {
  const AppBrandLogoHeader({
    super.key,
    this.margin,
    this.errorLabelStyle,
    this.maxWidth = 320,
  });

  final EdgeInsetsGeometry? margin;
  final TextStyle? errorLabelStyle;

  /// أقصى عرض للشعار (بكسل منطقي). فوقه لا يُكبَّر أكثر مهما اتسع المكان.
  final double maxWidth;

  static double _effectiveMaxWidth(BuildContext context, double cap) {
    final w = MediaQuery.sizeOf(context).width;
    final roughPadding = 48.0;
    return min(cap, (w - roughPadding).clamp(120.0, cap));
  }

  @override
  Widget build(BuildContext context) {
    final effectiveMax = _effectiveMaxWidth(context, maxWidth);
    return Container(
      width: double.infinity,
      margin: margin,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMax),
        child: AspectRatio(
          aspectRatio: AppBrand.logoImageAspectRatio,
          child: Image.asset(
            AppBrand.logoAsset,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppColors.background,
                child: Center(
                  child: Text(
                    AppBrand.displayName,
                    style: errorLabelStyle ??
                        const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
