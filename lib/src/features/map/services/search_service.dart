import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/map_marker.dart';
import 'geocoding_service.dart';

class SearchService {
  final GeocodingService _geocodingService;
  
  SearchService(this._geocodingService);

  Future<List<MapMarker>> searchLocations(String query) async {
    final results = await _geocodingService.searchPlaces(query);
    
    return results.map((place) {
      return MapMarker(
        id: 'search_${place['name']}',
        point: place['point'] as Point,
        title: place['name'] as String,
        subtitle: place['address'] as String,
        type: MarkerType.custom,
      );
    }).toList();
  }

  Future<List<String>> searchAddresses(String query) async {
    final results = await _geocodingService.searchPlaces(query);
    return results.map((place) => place['address'] as String).toList();
  }

  Future<List<MapMarker>> searchNearbyPlaces(Point center, {double radius = 1000}) async {
    // Note: This is a placeholder. Mapbox's nearby search requires additional setup
    // and possibly a different API endpoint
    return [];
  }
}

enum SearchType {
  location,
  address,
  nearby,
} 