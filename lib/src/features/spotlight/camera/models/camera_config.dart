import 'package:flutter/material.dart';

class CameraConfig {
  final double resolution;
  final bool enableAudio;
  final bool enable3D;
  final bool enable360;
  /// عند false تُستخدم صورة الكاميرا كما هي دون تمريرها على خدمة العلامة المائية.
  final bool applyWatermark;
  final String watermarkText;
  final double watermarkOpacity;
  final Color watermarkColor;
  final double watermarkSize;
  final Position watermarkPosition;

  /// [enableAudio] افتراضياً false لتفادي تعارض الميكروفون مع تهيئة الكاميرا على بعض الأجهزة.
  const CameraConfig({
    this.resolution = 1080,
    this.enableAudio = false,
    this.enable3D = false,
    this.enable360 = false,
    this.applyWatermark = true,
    this.watermarkText = 'دار كار',
    this.watermarkOpacity = 0.8,
    this.watermarkColor = const Color(0xFFFFFFFF),
    this.watermarkSize = 24,
    this.watermarkPosition = Position.bottomRight,
  });

  CameraConfig copyWith({
    double? resolution,
    bool? enableAudio,
    bool? enable3D,
    bool? enable360,
    bool? applyWatermark,
    String? watermarkText,
    double? watermarkOpacity,
    Color? watermarkColor,
    double? watermarkSize,
    Position? watermarkPosition,
  }) {
    return CameraConfig(
      resolution: resolution ?? this.resolution,
      enableAudio: enableAudio ?? this.enableAudio,
      enable3D: enable3D ?? this.enable3D,
      enable360: enable360 ?? this.enable360,
      applyWatermark: applyWatermark ?? this.applyWatermark,
      watermarkText: watermarkText ?? this.watermarkText,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      watermarkColor: watermarkColor ?? this.watermarkColor,
      watermarkSize: watermarkSize ?? this.watermarkSize,
      watermarkPosition: watermarkPosition ?? this.watermarkPosition,
    );
  }
}

enum Position {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
} 