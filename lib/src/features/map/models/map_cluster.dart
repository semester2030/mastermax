import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'map_marker.dart';

class MapCluster {
  final String id;
  final Point point;
  final List<MapMarker> markers;

  MapCluster({
    required this.id,
    required this.point,
    required this.markers,
  });

  int get size => markers.length;

  void addMarker(MapMarker marker) {
    markers.add(marker);
  }

  bool isCluster() => markers.length > 1;
} 