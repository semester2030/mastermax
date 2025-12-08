import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/utils/logger.dart';
import '../../../core/errors/exceptions.dart';

/// خدمة إدارة مواقع العقارات
class PropertyLocationService {
  /// الحصول على الموقع الحالي
  Future<Point> getCurrentLocation() async {
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
      return Point(
        coordinates: Position(
          position.longitude,
          position.latitude,
        ),
      );
    } catch (e) {
      throw LocationException('فشل في الحصول على الموقع الحالي: $e');
    }
  }

  /// تحويل العنوان إلى إحداثيات
  Future<Point> getLocationFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return Point(
          coordinates: Position(
            location.longitude.toDouble(),
            location.latitude.toDouble(),
          ),
        );
      }
      throw const LocationException('لم يتم العثور على الموقع');
    } catch (e) {
      throw LocationException('فشل في الحصول على الموقع: $e');
    }
  }

  /// تحويل الإحداثيات إلى عنوان
  Future<String> getAddressFromLocation(Point location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.coordinates.lat.toDouble(),
        location.coordinates.lng.toDouble(),
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
  Future<double> calculateDistance(Point start, Point end) async {
    try {
      return geo.Geolocator.distanceBetween(
        start.coordinates.lat.toDouble(),
        start.coordinates.lng.toDouble(),
        end.coordinates.lat.toDouble(),
        end.coordinates.lng.toDouble(),
      );
    } catch (e) {
      throw LocationException('فشل في حساب المسافة: $e');
    }
  }

  /// التحقق من وجود العقار ضمن نطاق محدد
  Future<bool> isPropertyWithinRange(Point propertyLocation, Point centerPoint, double radiusInMeters) async {
    final double distance = await calculateDistance(propertyLocation, centerPoint);
    return distance <= radiusInMeters;
  }

  /// الحصول على العقارات القريبة
  Future<List<Point>> getNearbyProperties(List<Point> allProperties, Point centerPoint, double radiusInMeters) async {
    final List<Point> nearbyProperties = [];
    for (var property in allProperties) {
      if (await isPropertyWithinRange(property, centerPoint, radiusInMeters)) {
        nearbyProperties.add(property);
      }
    }
    return nearbyProperties;
  }

  /// التحقق من صحة الإحداثيات
  bool isValidCoordinate(Point position) {
    try {
      return position.coordinates.lat >= -90 &&
          position.coordinates.lat <= 90 &&
          position.coordinates.lng >= -180 &&
          position.coordinates.lng <= 180;
    } catch (e) {
      logError('Error validating coordinates', e);
      rethrow;
    }
  }

  /// الحصول على حدود منطقة معينة من مجموعة نقاط
  CoordinateBounds getBoundsForPoints(List<Point> points) {
    if (points.isEmpty) {
      throw Exception('لا توجد نقاط لحساب الحدود');
    }

    double minLat = points.first.coordinates.lat.toDouble();
    double maxLat = points.first.coordinates.lat.toDouble();
    double minLng = points.first.coordinates.lng.toDouble();
    double maxLng = points.first.coordinates.lng.toDouble();

    for (final point in points) {
      final lat = point.coordinates.lat.toDouble();
      final lng = point.coordinates.lng.toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    return CoordinateBounds(
      southwest: Point(coordinates: Position(minLng, minLat)),
      northeast: Point(coordinates: Position(maxLng, maxLat)),
      infiniteBounds: false
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