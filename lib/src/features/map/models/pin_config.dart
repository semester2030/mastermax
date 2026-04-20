import 'package:flutter/material.dart';

class PinConfig {
  final Color color;
  final double size;
  final String? label;
  final IconData? icon;
  final Color? iconColor;
  final bool showGlow;

  const PinConfig({
    required this.color,
    this.size = 40.0,
    this.label,
    this.icon,
    this.iconColor,
    this.showGlow = false,
  });

  PinConfig copyWith({
    Color? color,
    double? size,
    String? label,
    IconData? icon,
    Color? iconColor,
    bool? showGlow,
  }) {
    return PinConfig(
      color: color ?? this.color,
      size: size ?? this.size,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      showGlow: showGlow ?? this.showGlow,
    );
  }
}

enum PinGlyph {
  home,
  car,
  location,
  star,
  custom,
}

