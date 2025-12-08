import 'package:flutter/material.dart';
import 'media_metadata.dart';

class CameraResult {
  final String id;
  final String path;
  final MediaType type;
  final DateTime timestamp;
  final MediaMetadata metadata;
  final Size dimensions;
  final double fileSize;
  final String? audioPath;
  final Map<String, dynamic>? additionalData;

  CameraResult({
    required this.id,
    required this.path,
    required this.type,
    required this.timestamp,
    required this.metadata,
    required this.dimensions,
    required this.fileSize,
    this.audioPath,
    this.additionalData,
  });

  bool get hasAudio => audioPath != null;
  bool get is3D => type == MediaType.threeDimensional;
  bool get is360 => type == MediaType.panoramic;
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'type': type.toString(),
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata.toJson(),
      'dimensions': {
        'width': dimensions.width,
        'height': dimensions.height,
      },
      'fileSize': fileSize,
      'audioPath': audioPath,
      'additionalData': additionalData,
    };
  }

  factory CameraResult.fromJson(Map<String, dynamic> json) {
    return CameraResult(
      id: json['id'],
      path: json['path'],
      type: MediaType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => MediaType.image,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      metadata: MediaMetadata.fromJson(json['metadata']),
      dimensions: Size(
        json['dimensions']['width'],
        json['dimensions']['height'],
      ),
      fileSize: json['fileSize'],
      audioPath: json['audioPath'],
      additionalData: json['additionalData'],
    );
  }
}

enum MediaType {
  image,
  video,
  panoramic,
  threeDimensional,
} 