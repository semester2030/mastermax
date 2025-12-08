import 'package:flutter/material.dart';

class PanoramaHotspot {
  final String id;
  final String title;
  final String description;
  final double longitude;
  final double latitude;
  final IconData icon;
  final Color color;

  const PanoramaHotspot({
    required this.id,
    required this.title,
    required this.description,
    required this.longitude,
    required this.latitude,
    this.icon = Icons.place,
    this.color = Colors.white,
  });

  factory PanoramaHotspot.fromJson(Map<String, dynamic> json) {
    return PanoramaHotspot(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      longitude: json['longitude'] as double,
      latitude: json['latitude'] as double,
      icon: IconData(json['icon'] as int, fontFamily: 'MaterialIcons'),
      color: Color(json['color'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'longitude': longitude,
      'latitude': latitude,
      'icon': icon.codePoint,
      'color': color.value,
    };
  }

  PanoramaHotspot copyWith({
    String? id,
    String? title,
    String? description,
    double? longitude,
    double? latitude,
    IconData? icon,
    Color? color,
  }) {
    return PanoramaHotspot(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
} 