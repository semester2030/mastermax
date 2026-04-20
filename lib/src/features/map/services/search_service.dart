import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/map_marker.dart';
import 'geocoding_service.dart';
import 'places_service.dart';

class SearchService {
  final GeocodingService _geocodingService;
  final PlacesService _placesService = PlacesService();
  
  SearchService(this._geocodingService);

  Future<List<MapMarker>> searchLocations(String query) async {
    final results = await _geocodingService.searchPlaces(query);
    
    return results.map((place) {
      return MapMarker(
        id: 'search_${place['name']}',
        position: place['location'] as LatLng,
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

  Future<List<MapMarker>> searchNearbyPlaces(LatLng center, {double radius = 1000}) async {
    final results = await _placesService.nearbySearch(
      location: center,
      radius: radius,
    );
    
    return results.map((place) {
      return MapMarker(
        id: 'nearby_${place['place_id']}',
        position: place['location'] as LatLng,
        title: place['name'] as String,
        subtitle: place['address'] as String,
        type: MarkerType.custom,
      );
    }).toList();
  }
}

enum SearchType {
  location,
  address,
  nearby,
} 