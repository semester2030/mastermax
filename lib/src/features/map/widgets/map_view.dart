import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/map_state.dart';
import '../models/map_marker.dart';
import '../models/map_cluster.dart';
import 'map_markers.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late MapState _mapState;

  @override
  void initState() {
    super.initState();
    _mapState = context.read<MapState>();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapState>(
      builder: (context, state, child) {
        return Stack(
          children: [
            MapWidget(
              key: const ValueKey('mapView'),
              onMapCreated: _mapState.setController,
              styleUri: MapboxStyles.MAPBOX_STREETS,
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(46.6753, 24.7136),
                ),
                zoom: 12,
              ),
            ),
            if (state.markers.isNotEmpty || state.clusters.isNotEmpty)
              MapMarkers(
                markers: state.markers,
                clusters: state.clusters,
                onMarkerTap: _onMarkerTap,
                onClusterTap: _onClusterTap,
              ),
          ],
        );
      },
    );
  }

  void _onMarkerTap(MapMarker marker) {
    // Handle marker tap
  }

  void _onClusterTap(MapCluster cluster) {
    // Handle cluster tap
  }
} 