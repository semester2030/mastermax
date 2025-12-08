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
    this.color = Colors.blue,
    this.specificationKey,
    this.specificationValue,
    this.isInterior = false,
  });

  factory CarHotspot.fromJson(Map<String, dynamic> json) {
    return CarHotspot(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      longitude: json['longitude'] as double,
      latitude: json['latitude'] as double,
      icon: IconData(json['icon'] as int, fontFamily: 'MaterialIcons'),
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