import 'package:flutter/material.dart';

class CarHotspot {
  final String id;
  final String title;
  final String description;
  final double longitude;
  final double latitude;
  final IconData icon;
  final Color color;
  final String? specificationKey;
  final String? specificationValue;
  final bool isInterior;

  const CarHotspot({
    required this.id,
    required this.title,
    required this.description,
    required this.longitude,
    required this.latitude,
    this.icon = Icons.info,
    this.color = const Color(0xFF2196F3),
    this.specificationKey,
    this.specificationValue,
    this.isInterior = false,
  });

  /// يعيد أيقونة Material معروفة فقط (ثابتة) لتمرير تحليل أيقونات الويب (tree-shake).
  static IconData _iconFromCodePoint(int codePoint) {
    if (codePoint == Icons.info.codePoint) return Icons.info;
    if (codePoint == Icons.directions_car.codePoint) return Icons.directions_car;
    if (codePoint == Icons.tire_repair.codePoint) return Icons.tire_repair;
    if (codePoint == Icons.highlight.codePoint) return Icons.highlight;
    if (codePoint == Icons.dashboard.codePoint) return Icons.dashboard;
    if (codePoint == Icons.event_seat.codePoint) return Icons.event_seat;
    if (codePoint == Icons.wb_sunny.codePoint) return Icons.wb_sunny;
    return Icons.info;
  }

  factory CarHotspot.fromJson(Map<String, dynamic> json) {
    final iconCode = json['icon'] as int? ?? Icons.info.codePoint;
    return CarHotspot(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      longitude: json['longitude'] as double,
      latitude: json['latitude'] as double,
      icon: _iconFromCodePoint(iconCode),
      color: Color(json['color'] as int),
      specificationKey: json['specificationKey'] as String?,
      specificationValue: json['specificationValue'] as String?,
      isInterior: json['isInterior'] as bool? ?? false,
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
      'specificationKey': specificationKey,
      'specificationValue': specificationValue,
      'isInterior': isInterior,
    };
  }

  CarHotspot copyWith({
    String? id,
    String? title,
    String? description,
    double? longitude,
    double? latitude,
    IconData? icon,
    Color? color,
    String? specificationKey,
    String? specificationValue,
    bool? isInterior,
  }) {
    return CarHotspot(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      specificationKey: specificationKey ?? this.specificationKey,
      specificationValue: specificationValue ?? this.specificationValue,
      isInterior: isInterior ?? this.isInterior,
    );
  }
} 