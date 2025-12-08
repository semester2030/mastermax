import 'package:flutter/material.dart';
import '../theme/app_animations.dart';

/// زر متحرك جاهز للاستخدام
class AnimatedButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool isEnabled;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final BoxDecoration? decoration;

  const AnimatedButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.isEnabled = true,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return AppAnimations.animatedButton(
      onPressed: onPressed,
      isEnabled: isEnabled,
      padding: padding,
      borderRadius: borderRadius,
      child: Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: decoration ?? BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

/// بطاقة متحركة جاهزة للاستخدام
class AnimatedCard extends StatelessWidget {
  final Widget child;
  final bool isHovered;
  final double elevation;
  final Color? hoverColor;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final BoxDecoration? decoration;

  const AnimatedCard({
    super.key,
    required this.child,
    this.isHovered = false,
    this.elevation = 12,
    this.hoverColor,
    this.borderRadius,
    this.padding,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return AppAnimations.hoverCard(
      isHovered: isHovered,
      elevation: elevation,
      hoverColor: hoverColor,
      borderRadius: borderRadius,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: decoration ?? BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

/// بطاقة زجاجية جاهزة للاستخدام
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 12,
    this.opacity = 0.18,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return AppAnimations.glassCard(
      blur: blur,
      opacity: opacity,
      borderRadius: borderRadius,
      padding: padding,
      backgroundColor: backgroundColor,
      border: border,
      boxShadow: boxShadow,
      child: child,
    );
  }
}

/// نص متحرك جاهز للاستخدام
class AnimatedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Duration? duration;
  final Curve? curve;
  final TextAlign? textAlign;

  const AnimatedText({
    super.key,
    required this.text,
    required this.style,
    this.duration,
    this.curve,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return AppAnimations.animatedText(
      text: text,
      style: style,
      duration: duration,
      curve: curve,
      textAlign: textAlign,
    );
  }
}

/// نص متدرج متحرك جاهز للاستخدام
class ShimmerText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color? baseColor;
  final Color? highlightColor;
  final bool isLoading;
  final TextAlign? textAlign;

  const ShimmerText({
    super.key,
    required this.text,
    required this.style,
    this.baseColor,
    this.highlightColor,
    this.isLoading = false,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return AppAnimations.shimmerText(
      text: text,
      style: style,
      baseColor: baseColor,
      highlightColor: highlightColor,
      isLoading: isLoading,
      textAlign: textAlign,
    );
  }
}

/// صورة متحركة جاهزة للاستخدام
class AnimatedImage extends StatelessWidget {
  final Widget child;
  final bool isHovered;
  final double scale;

  const AnimatedImage({
    super.key,
    required this.child,
    this.isHovered = false,
    this.scale = 1.05,
  });

  @override
  Widget build(BuildContext context) {
    return AppAnimations.imageHover(
      child: child,
      isHovered: isHovered,
      scale: scale,
    );
  }
}

/// مؤشر تحميل متدرج جاهز للاستخدام
class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppAnimations.shimmerLoading(
      child: child,
      isLoading: isLoading,
      baseColor: baseColor,
      highlightColor: highlightColor,
    );
  }
}

/// تأثير ظهور/اختفاء جاهز للاستخدام
class FadeScale extends StatelessWidget {
  final Widget child;
  final bool isVisible;
  final Duration? duration;
  final Curve? curve;

  const FadeScale({
    super.key,
    required this.child,
    required this.isVisible,
    this.duration,
    this.curve,
  });

  @override
  Widget build(BuildContext context) {
    return AppAnimations.fadeScale(
      child: child,
      isVisible: isVisible,
      duration: duration,
      curve: curve,
    );
  }
} 