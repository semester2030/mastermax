import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/exceptions.dart';
import 'package:flutter/foundation.dart';
import 'places_service.dart';

class GeocodingService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = '$_baseUrl?address=$encodedAddress&key=${AppConfig.mapApiKey}&language=ar&region=sa';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(
            location['lat'].toDouble(),
            location['lng'].toDouble(),
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error in getCoordinatesFromAddress: $e');
      throw LocationException('فشل في الحصول على الإحداثيات: $e');
    }
  }

  Future<String?> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      final url = '$_baseUrl?latlng=${coordinates.latitude},${coordinates.longitude}&key=${AppConfig.mapApiKey}&language=ar&region=sa';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'] as String;
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
      final placesService = PlacesService();
      return await placesService.searchPlaces(query: query);
    } catch (e) {
      debugPrint('Error in searchPlaces: $e');
      throw LocationException('فشل في البحث عن الأماكن: $e');
    }
  }
} 