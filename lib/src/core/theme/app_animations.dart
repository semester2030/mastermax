import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_colors.dart';
import 'dart:ui';

class AppAnimations {
  // مدة التأثيرات
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 600);

  // منحنيات الحركة
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeOutCubic;

  /// زر متفاعل مع Hover وTap وRipple
  static Widget animatedButton({
    required Widget child,
    required VoidCallback onPressed,
    bool isEnabled = true,
    double scale = 0.98,
    EdgeInsets? padding,
    Color? rippleColor,
    BorderRadius? borderRadius,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        bool isPressed = false;
        
        // ignore: dead_code
        final double currentScale = isPressed 
            ? scale 
            // ignore: dead_code
            : (kIsWeb && isHovered) 
                ? 1.03 
                : 1.0;
        
        Widget buttonContent = GestureDetector(
          onTapDown: (_) => setState(() => isPressed = true),
          onTapUp: (_) => setState(() => isPressed = false),
          onTapCancel: () => setState(() => isPressed = false),
          onTap: isEnabled ? onPressed : null,
          child: AnimatedScale(
            scale: currentScale,
            duration: short,
            curve: defaultCurve,
            child: Material(
              color: Colors.transparent,
              borderRadius: borderRadius,
              child: InkWell(
                borderRadius: borderRadius,
                splashColor: rippleColor ?? AppColors.primary.withOpacity(0.08),
                highlightColor: rippleColor ?? AppColors.primary.withOpacity(0.04),
                onTap: isEnabled ? onPressed : null,
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ),
            ),
          ),
        );
        
        // ✅ إضافة MouseRegion فقط على Web
        if (kIsWeb) {
          return MouseRegion(
            onEnter: (_) => setState(() => isHovered = true),
            onExit: (_) => setState(() => isHovered = false),
            child: buttonContent,
          );
        }
        
        return buttonContent;
      },
    );
  }

  /// بطاقة تفاعلية مع Hover وShadow
  static Widget hoverCard({
    required Widget child,
    bool isHovered = false,
    double elevation = 12,
    Color? hoverColor,
    BorderRadius? borderRadius,
    List<BoxShadow>? shadow,
  }) {
    return AnimatedContainer(
      duration: short,
      curve: defaultCurve,
      decoration: BoxDecoration(
        color: isHovered ? (hoverColor ?? AppColors.primary.withOpacity(0.03)) : Colors.transparent,
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        boxShadow: isHovered
            ? shadow ?? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.10),
                  blurRadius: elevation,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  /// تأثير Fade + Scale للظهور/الاختفاء
  static Widget fadeScale({
    required Widget child,
    required bool isVisible,
    Duration? duration,
    Curve? curve,
  }) {
    return AnimatedOpacity(
      duration: duration ?? medium,
      curve: curve ?? defaultCurve,
      opacity: isVisible ? 1.0 : 0.0,
      child: AnimatedScale(
        duration: duration ?? medium,
        curve: curve ?? defaultCurve,
        scale: isVisible ? 1.0 : 0.96,
        child: child,
      ),
    );
  }

  /// نص متدرج متحرك (Shimmer)
  static Widget shimmerText({
    required String text,
    required TextStyle style,
    Color? baseColor,
    Color? highlightColor,
    bool isLoading = false,
    TextAlign? textAlign,
  }) {
    return isLoading
        ? ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                baseColor ?? AppColors.primary.withOpacity(0.5),
                highlightColor ?? AppColors.brightGold,
                baseColor ?? AppColors.primary.withOpacity(0.5),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              text,
              style: style.copyWith(color: Colors.white),
              textAlign: textAlign,
            ),
          )
        : Text(text, style: style, textAlign: textAlign);
  }

  /// بطاقة زجاجية (Glassmorphism)
  static Widget glassCard({
    required Widget child,
    double blur = 12,
    double opacity = 0.18,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
    Color? backgroundColor,
    BoxBorder? border,
    List<BoxShadow>? boxShadow,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (backgroundColor ?? AppColors.white).withOpacity(opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: border ?? Border.all(color: AppColors.primary.withOpacity(0.08)),
            boxShadow: boxShadow ?? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  /// نص متحرك عند التغيير
  static Widget animatedText({
    required String text,
    required TextStyle style,
    Duration? duration,
    Curve? curve,
    TextAlign? textAlign,
  }) {
    return AnimatedDefaultTextStyle(
      duration: duration ?? medium,
      curve: curve ?? defaultCurve,
      style: style,
      child: Text(text, textAlign: textAlign),
    );
  }

  /// مؤشر تحميل متدرج (Shimmer)
  static Widget shimmerLoading({
    required Widget child,
    bool isLoading = true,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return AnimatedSwitcher(
      duration: medium,
      child: isLoading
          ? ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  baseColor ?? AppColors.primaryLight,
                  highlightColor ?? AppColors.primaryLightLighter,
                  baseColor ?? AppColors.primaryLight,
                ],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: child,
            )
          : child,
    );
  }

  /// تأثير صورة عند التحويم
  static Widget imageHover({
    required Widget child,
    required bool isHovered,
    double scale = 1.05,
  }) {
    return AnimatedScale(
      scale: isHovered ? scale : 1.0,
      duration: short,
      curve: defaultCurve,
      child: child,
    );
  }
} 