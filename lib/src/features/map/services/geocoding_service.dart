import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/errors/exceptions.dart';
import 'package:flutter/foundation.dart';

class GeocodingService {
  static const String _accessToken = 'pk.eyJ1IjoiZmF6MjAiLCJhIjoiY202cXYyZ20wMW9wNTJpc2h0cXF5cG1qbyJ9.00-UGiXUfPqWXl_Pvs9zsA';
  static const String _baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  Future<Point?> getCoordinatesFromAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = '$_baseUrl/$encodedAddress.json?access_token=$_accessToken&country=SA&language=ar';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        if (features.isNotEmpty) {
          final coordinates = features[0]['center'] as List;
          return Point(
            coordinates: Position(
              coordinates[0], // longitude
              coordinates[1], // latitude
            ),
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error in getCoordinatesFromAddress: $e');
      throw LocationException('فشل في الحصول على الإحداثيات: $e');
    }
  }

  Future<String?> getAddressFromCoordinates(Point point) async {
    try {
      final url = '$_baseUrl/${point.coordinates.lng},${point.coordinates.lat}.json?access_token=$_accessToken&language=ar';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        if (features.isNotEmpty) {
          return features[0]['place_name'] as String;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error in getAddressFromCoordinates: $e');
      throw LocationException('فشل في الحصول على العنوان: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$_baseUrl/$encodedQuery.json?access_token=$_accessToken&country=SA&language=ar';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        return features.map((feature) {
          final coordinates = feature['center'] as List;
          return {
            'address': feature['place_name'] as String,
            'point': Point(
              coordinates: Position(
                coordinates[0], // longitude
                coordinates[1], // latitude
              ),
            ),
            'type': feature['place_type'][0] as String,
            'name': feature['text'] as String,
          };
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error in searchPlaces: $e');
      throw LocationException('فشل في البحث عن الأماكن: $e');
    }
  }
} 