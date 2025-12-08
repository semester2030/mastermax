import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:typed_data';

class MapMarker {
  final String id;
  final Point point;
  final String title;
  final String? subtitle;
  final MarkerType type;
  final String? imageUrl;
  final Uint8List? imageData;

  MapMarker({
    required this.id,
    required this.point,
    required this.title,
    required this.type, this.subtitle,
    this.imageUrl,
    this.imageData,
  });

  double get latitude => point.coordinates.lat.toDouble();
  double get longitude => point.coordinates.lng.toDouble();

  PointAnnotationOptions toAnnotationOptions() {
    return PointAnnotationOptions(
      geometry: point,
      textField: title,
      textSize: 12,
      textOffset: [0, 2],
      textColor: 0xFF000000,
      textHaloColor: 0xFFFFFFFF,
      textHaloWidth: 1.0,
      iconSize: 1.2,
      image: imageData,
    );
  }
}

enum MarkerType {
  property,
  car,
  user,
  custom
} 