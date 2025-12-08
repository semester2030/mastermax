import 'package:flutter/material.dart';
import '../models/map_marker.dart';
import '../models/map_cluster.dart';

class MapMarkers extends StatelessWidget {
  final List<MapMarker> markers;
  final List<MapCluster> clusters;
  final Function(MapMarker)? onMarkerTap;
  final Function(MapCluster)? onClusterTap;

  const MapMarkers({
    required this.markers, required this.clusters, super.key,
    this.onMarkerTap,
    this.onClusterTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Stack(
        children: [
          ...markers.map((marker) => _buildMarkerWidget(context, marker)),
          ...clusters.map((cluster) => _buildClusterWidget(context, cluster)),
        ],
      ),
    );
  }

  Widget _buildMarkerWidget(BuildContext context, MapMarker marker) {
    return Positioned(
      left: marker.point.coordinates.lng.toDouble(),
      top: marker.point.coordinates.lat.toDouble(),
      child: GestureDetector(
        onTap: () => onMarkerTap?.call(marker),
        child: _MarkerIcon(
          title: marker.title,
          type: marker.type,
        ),
      ),
    );
  }

  Widget _buildClusterWidget(BuildContext context, MapCluster cluster) {
    return Positioned(
      left: cluster.point.coordinates.lng.toDouble(),
      top: cluster.point.coordinates.lat.toDouble(),
      child: GestureDetector(
        onTap: () => onClusterTap?.call(cluster),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            cluster.size.toString(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerIcon extends StatelessWidget {
  final String title;
  final MarkerType type;

  const _MarkerIcon({
    required this.title,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getColorForType(type, context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getColorForType(MarkerType type, BuildContext context) {
    switch (type) {
      case MarkerType.property:
        return Theme.of(context).colorScheme.primary;
      case MarkerType.car:
        return Theme.of(context).colorScheme.secondary;
      case MarkerType.user:
        return Theme.of(context).colorScheme.error;
      case MarkerType.custom:
        return Theme.of(context).colorScheme.tertiary;
    }
  }
} 