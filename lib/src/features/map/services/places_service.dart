import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/config/app_config.dart';
import 'package:flutter/foundation.dart';

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  Future<List<Map<String, dynamic>>> searchPlaces({
    required String query,
    LatLng? location,
    double radius = 5000,
    String? type,
  }) async {
    try {
      final locationParam = location != null
          ? '&location=${location.latitude},${location.longitude}&radius=$radius'
          : '';
      final typeParam = type != null ? '&type=$type' : '';
      
      final url = '$_baseUrl/textsearch/json?query=${Uri.encodeComponent(query)}'
          '$locationParam'
          '$typeParam'
          '&key=${AppConfig.mapApiKey}'
          '&language=ar';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return (data['results'] as List).map((place) {
            final location = place['geometry']['location'];
            return {
              'place_id': place['place_id'],
              'name': place['name'],
              'address': place['formatted_address'],
              'location': LatLng(
                location['lat'].toDouble(),
                location['lng'].toDouble(),
              ),
              'rating': place['rating']?.toDouble(),
              'types': place['types'] as List,
              'photos': place['photos'],
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error in searchPlaces: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> nearbySearch({
    required LatLng location,
    double radius = 1000,
    String? type,
    String? keyword,
    bool rankByDistance = true, // ✅ ترتيب حسب المسافة
  }) async {
    try {
      final typeParam = type != null ? '&type=$type' : '';
      final keywordParam = keyword != null ? '&keyword=${Uri.encodeComponent(keyword)}' : '';
      
      // ✅ إذا كان rankByDistance = true، يجب عدم استخدام radius (مطلوب من Google)
      final rankParam = rankByDistance ? '&rankby=distance' : '&radius=$radius';
      
      final url = '$_baseUrl/nearbysearch/json?location=${location.latitude},${location.longitude}'
          '$rankParam'
          '$typeParam'
          '$keywordParam'
          '&key=${AppConfig.mapApiKey}'
          '&language=ar';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = (data['results'] as List).map((place) {
            final placeLocation = place['geometry']['location'];
            final placeLatLng = LatLng(
              placeLocation['lat'].toDouble(),
              placeLocation['lng'].toDouble(),
            );
            
            // ✅ حساب المسافة الفعلية من موقع البحث
            final distance = _calculateDistance(location, placeLatLng);
            
            return {
              'place_id': place['place_id'],
              'name': place['name'],
              'address': place['vicinity'] ?? place['formatted_address'],
              'location': placeLatLng,
              'rating': place['rating']?.toDouble(),
              'types': place['types'] as List,
              'distance': distance, // ✅ إضافة المسافة المحسوبة
            };
          }).toList();
          
          // ✅ ترتيب حسب المسافة (الأقرب أولاً)
          results.sort((a, b) {
            final distA = a['distance'] as double;
            final distB = b['distance'] as double;
            return distA.compareTo(distB);
          });
          
          return results;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error in nearbySearch: $e');
      return [];
    }
  }
  
  /// ✅ حساب المسافة بين موقعين بالأمتار (Haversine formula)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // متر
    final double lat1Rad = point1.latitude * (math.pi / 180);
    final double lat2Rad = point2.latitude * (math.pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);
    
    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final url = '$_baseUrl/details/json?place_id=$placeId'
          '&fields=name,formatted_address,geometry,rating,photos,types,website,international_phone_number'
          '&key=${AppConfig.mapApiKey}'
          '&language=ar';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final place = data['result'];
          final location = place['geometry']['location'];
          return {
            'place_id': place['place_id'],
            'name': place['name'],
            'address': place['formatted_address'],
            'location': LatLng(
              location['lat'].toDouble(),
              location['lng'].toDouble(),
            ),
            'rating': place['rating']?.toDouble(),
            'types': place['types'] as List,
            'photos': place['photos'],
            'website': place['website'],
            'phone': place['international_phone_number'],
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error in getPlaceDetails: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> autocomplete({
    required String input,
    LatLng? location,
    double radius = 5000,
    String? type,
  }) async {
    try {
      final locationParam = location != null
          ? '&location=${location.latitude},${location.longitude}&radius=$radius'
          : '';
      final typeParam = type != null ? '&types=$type' : '';
      
      final url = '$_baseUrl/autocomplete/json?input=${Uri.encodeComponent(input)}'
          '$locationParam'
          '$typeParam'
          '&key=${AppConfig.mapApiKey}'
          '&language=ar';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return (data['predictions'] as List).map((prediction) {
            return {
              'place_id': prediction['place_id'],
              'description': prediction['description'],
              'structured_formatting': prediction['structured_formatting'],
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error in autocomplete: $e');
      return [];
    }
  }
}

