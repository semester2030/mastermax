import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:typed_data';

class MapMarker {
  final String id;
  final LatLng position;
  final String title;
  final String? subtitle;
  final MarkerType type;
  final String? imageUrl;
  final Uint8List? imageData;
  final BitmapDescriptor? icon;

  MapMarker({
    required this.id,
    required this.position,
    required this.title,
    required this.type,
    this.subtitle,
    this.imageUrl,
    this.imageData,
    this.icon,
  });

  double get latitude => position.latitude;
  double get longitude => position.longitude;

  Marker toGoogleMarker({Function(MarkerId)? onTap}) {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(
        title: title,
        snippet: subtitle,
      ),
      icon: icon ?? BitmapDescriptor.defaultMarker,
      onTap: onTap != null ? () => onTap(MarkerId(id)) : null,
    );
  }
}

enum MarkerType {
  property,
  car,
  user,
  custom
} 