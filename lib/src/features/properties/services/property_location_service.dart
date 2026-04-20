import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/utils/logger.dart';
import '../../../core/errors/exceptions.dart';

/// خدمة إدارة مواقع العقارات
class PropertyLocationService {
  /// الحصول على الموقع الحالي
  Future<LatLng> getCurrentLocation() async {
    try {
      final permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        final newPermission = await geo.Geolocator.requestPermission();
        if (newPermission == geo.LocationPermission.denied) {
          throw const LocationException('تم رفض إذن الموقع');
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        throw const LocationException('تم رفض إذن الموقع بشكل دائم');
      }

      final position = await geo.Geolocator.getCurrentPosition();
      return LatLng(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      throw LocationException('فشل في الحصول على الموقع الحالي: $e');
    }
  }

  /// تحويل العنوان إلى إحداثيات
  Future<LatLng> getLocationFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return LatLng(
          location.latitude,
          location.longitude,
        );
      }
      throw const LocationException('لم يتم العثور على الموقع');
    } catch (e) {
      throw LocationException('فشل في الحصول على الموقع: $e');
    }
  }

  /// تحويل الإحداثيات إلى عنوان
  Future<String> getAddressFromLocation(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return _formatAddress(place);
      }
      return 'عنوان غير معروف';
    } catch (e) {
      throw LocationException('فشل في الحصول على العنوان: $e');
    }
  }

  /// حساب المسافة بين موقعين بالأمتار
  double calculateDistance(LatLng start, LatLng end) {
    try {
      return geo.Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );
    } catch (e) {
      throw LocationException('فشل في حساب المسافة: $e');
    }
  }

  /// التحقق من وجود العقار ضمن نطاق محدد
  bool isPropertyWithinRange(LatLng propertyLocation, LatLng centerPoint, double radiusInMeters) {
    final double distance = calculateDistance(propertyLocation, centerPoint);
    return distance <= radiusInMeters;
  }

  /// الحصول على العقارات القريبة
  List<LatLng> getNearbyProperties(List<LatLng> allProperties, LatLng centerPoint, double radiusInMeters) {
    final List<LatLng> nearbyProperties = [];
    for (var property in allProperties) {
      if (isPropertyWithinRange(property, centerPoint, radiusInMeters)) {
        nearbyProperties.add(property);
      }
    }
    return nearbyProperties;
  }

  /// التحقق من صحة الإحداثيات
  bool isValidCoordinate(LatLng position) {
    try {
      return position.latitude >= -90 &&
          position.latitude <= 90 &&
          position.longitude >= -180 &&
          position.longitude <= 180;
    } catch (e) {
      logError('Error validating coordinates', e);
      rethrow;
    }
  }

  /// الحصول على حدود منطقة معينة من مجموعة نقاط
  LatLngBounds getBoundsForPoints(List<LatLng> points) {
    if (points.isEmpty) {
      throw Exception('لا توجد نقاط لحساب الحدود');
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  String _formatAddress(Placemark place) {
    final components = <String>[];

    if (place.street?.isNotEmpty ?? false) {
      components.add(place.street!);
    }
    if (place.subLocality?.isNotEmpty ?? false) {
      components.add(place.subLocality!);
    }
    if (place.locality?.isNotEmpty ?? false) {
      components.add(place.locality!);
    }
    if (place.administrativeArea?.isNotEmpty ?? false) {
      components.add(place.administrativeArea!);
    }
    if (place.country?.isNotEmpty ?? false) {
      components.add(place.country!);
    }

    return components.join('، ');
  }
} 