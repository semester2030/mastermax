import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/config/app_config.dart';
import 'package:flutter/foundation.dart';

enum TravelMode {
  driving,
  walking,
  bicycling,
  transit,
}

class DirectionsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
    TravelMode mode = TravelMode.driving,
    List<LatLng>? waypoints,
    bool avoidHighways = false,
    bool avoidTolls = false,
    bool avoidFerries = false,
  }) async {
    try {
      final modeString = _getModeString(mode);
      final waypointsParam = waypoints != null && waypoints.isNotEmpty
          ? '&waypoints=${waypoints.map((w) => '${w.latitude},${w.longitude}').join('|')}'
          : '';
      
      final avoidances = <String>[];
      if (avoidHighways) avoidances.add('highways');
      if (avoidTolls) avoidances.add('tolls');
      if (avoidFerries) avoidances.add('ferries');
      final avoidParam = avoidances.isNotEmpty
          ? '&avoid=${avoidances.join('|')}'
          : '';

      final url = '$_baseUrl?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=$modeString'
          '$waypointsParam'
          '$avoidParam'
          '&key=${AppConfig.mapApiKey}'
          '&language=ar';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          return data['routes'][0];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error in getDirections: $e');
      return null;
    }
  }

  Future<List<LatLng>> getRoutePoints({
    required LatLng origin,
    required LatLng destination,
    TravelMode mode = TravelMode.driving,
  }) async {
    final route = await getDirections(
      origin: origin,
      destination: destination,
      mode: mode,
    );

    if (route == null) return [];

    final points = <LatLng>[];
    final legs = route['legs'] as List;
    
    for (final leg in legs) {
      final steps = leg['steps'] as List;
      for (final step in steps) {
        final polyline = step['polyline']['points'] as String;
        points.addAll(_decodePolyline(polyline));
      }
    }

    return points;
  }

  Future<Map<String, dynamic>?> getRouteInfo({
    required LatLng origin,
    required LatLng destination,
    TravelMode mode = TravelMode.driving,
  }) async {
    final route = await getDirections(
      origin: origin,
      destination: destination,
      mode: mode,
    );

    if (route == null) return null;

    final legs = route['legs'] as List;
    double totalDistance = 0;
    int totalDuration = 0;
    final steps = <Map<String, dynamic>>[];

    for (final leg in legs) {
      totalDistance += (leg['distance']['value'] as int).toDouble();
      totalDuration += leg['duration']['value'] as int;
      
      final legSteps = leg['steps'] as List;
      for (final step in legSteps) {
        steps.add({
          'distance': step['distance']['text'],
          'duration': step['duration']['text'],
          'instruction': step['html_instructions'],
          'start_location': {
            'lat': step['start_location']['lat'],
            'lng': step['start_location']['lng'],
          },
          'end_location': {
            'lat': step['end_location']['lat'],
            'lng': step['end_location']['lng'],
          },
        });
      }
    }

    return {
      'distance': totalDistance,
      'distance_text': '${(totalDistance / 1000).toStringAsFixed(1)} km',
      'duration': totalDuration,
      'duration_text': '${(totalDuration / 60).toStringAsFixed(0)} دقيقة',
      'steps': steps,
      'polyline': route['overview_polyline']['points'],
    };
  }

  String _getModeString(TravelMode mode) {
    switch (mode) {
      case TravelMode.driving:
        return 'driving';
      case TravelMode.walking:
        return 'walking';
      case TravelMode.bicycling:
        return 'bicycling';
      case TravelMode.transit:
        return 'transit';
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}

