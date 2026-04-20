import 'dart:math' as math;
import '../models/map_cluster.dart';
import '../models/map_marker.dart';

class ClusteringService {
  static const double _clusterRadius = 50.0;

  List<MapCluster> createClusters(List<MapMarker> markers, double zoom) {
    if (markers.isEmpty) return [];

    final List<MapCluster> clusters = [];
    final double viewportRadius = _clusterRadius / math.pow(2, zoom);

    for (var marker in markers) {
      bool addedToCluster = false;

      for (var cluster in clusters) {
        if (_shouldAddToCluster(marker, cluster, viewportRadius)) {
          cluster.addMarker(marker);
          addedToCluster = true;
          break;
        }
      }

      if (!addedToCluster) {
        clusters.add(MapCluster(
          id: 'cluster_${clusters.length}',
          position: marker.position,
          markers: [marker],
        ));
      }
    }

    return clusters;
  }

  bool _shouldAddToCluster(MapMarker marker, MapCluster cluster, double radius) {
    final double distance = _calculateDistance(
      marker.latitude,
      marker.longitude,
      cluster.position.latitude,
      cluster.position.longitude,
    );
    return distance <= radius;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000.0; // meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }
} 