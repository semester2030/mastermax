import 'package:flutter/material.dart';

class CameraConfig {
  final double resolution;
  final bool enableAudio;
  final bool enable3D;
  final bool enable360;
  final String watermarkText;
  final double watermarkOpacity;
  final Color watermarkColor;
  final double watermarkSize;
  final Position watermarkPosition;

  CameraConfig({
    this.resolution = 1080,
    this.enableAudio = true,
    this.enable3D = false,
    this.enable360 = false,
    this.watermarkText = 'Master Max',
    this.watermarkOpacity = 0.8,
    this.watermarkColor = Colors.white,
    this.watermarkSize = 24,
    this.watermarkPosition = Position.bottomRight,
  });

  CameraConfig copyWith({
    double? resolution,
    bool? enableAudio,
    bool? enable3D,
    bool? enable360,
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