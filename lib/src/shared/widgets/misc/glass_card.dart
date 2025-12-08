import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? backgroundColor;

  const GlassCard({
    required this.child,
    super.key,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? colorScheme.surface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(borderRadius ?? 12),
            border: Border.all(
              color: colorScheme.surface.withOpacity(0.05),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
} 