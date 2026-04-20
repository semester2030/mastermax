import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_marker.dart';

class MapCluster {
  final String id;
  final LatLng position;
  final List<MapMarker> markers;

  MapCluster({
    required this.id,
    required this.position,
    required this.markers,
  });

  int get size => markers.length;

  void addMarker(MapMarker marker) {
    markers.add(marker);
  }

  bool isCluster() => markers.length > 1;
} 