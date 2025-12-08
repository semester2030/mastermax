import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapProperty {
  final String id;
  final String title;
  final String description;
  final Position coordinates;
  final double price;
  final String type;
  final List<String> images;
  final Map<String, dynamic> details;

  MapProperty({
    required this.id,
    required this.title,
    required this.description,
    required this.coordinates,
    required this.price,
    required this.type,
    required this.images,
    required this.details,
  });

  factory MapProperty.fromJson(Map<String, dynamic> json) {
    return MapProperty(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      coordinates: Position(
        json['latitude'] as double,
        json['longitude'] as double,
      ),
      price: json['price'] as double,
      type: json['type'] as String,
      images: List<String>.from(json['images'] as List),
      details: json['details'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'latitude': coordinates.lat,
      'longitude': coordinates.lng,
      'price': price,
      'type': type,
      'images': images,
      'details': details,
    };
  }

  MapProperty copyWith({
    String? id,
    String? title,
    String? description,
    Position? coordinates,
    double? price,
    String? type,
    List<String>? images,
    Map<String, dynamic>? details,
  }) {
    return MapProperty(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coordinates: coordinates ?? this.coordinates,
      price: price ?? this.price,
      type: type ?? this.type,
      images: images ?? this.images,
      details: details ?? this.details,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapProperty && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 