import 'package:location/location.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/errors/exceptions.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  final Location _location = Location();

  Future<bool> checkPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }

    return true;
  }

  Future<Point?> getCurrentLocation() async {
    try {
      if (!await checkPermissions()) {
        return null;
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        return Point(
          coordinates: Position(
            locationData.longitude!,
            locationData.latitude!,
          ),
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  Stream<Point?> getLocationStream() {
    return _location.onLocationChanged.map((locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        return Point(
          coordinates: Position(
            locationData.longitude!,
            locationData.latitude!,
          ),
        );
      }
      return null;
    });
  }

  Future<double> getLocationAccuracy() async {
    try {
      await checkPermissions();
      
      final locationData = await _location.getLocation();
      return locationData.accuracy ?? 0.0;
    } catch (e) {
      throw LocationException(e.toString());
    }
  }

  Future<void> enableBackgroundMode(bool enable) async {
    try {
      await _location.enableBackgroundMode(enable: enable);
    } catch (e) {
      throw LocationException(e.toString());
    }
  }

  Future<bool> isBackgroundModeEnabled() async {
    try {
      return await _location.isBackgroundModeEnabled();
    } catch (e) {
      throw LocationException(e.toString());
    }
  }

  Future<void> changeSettings({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int interval = 1000,
    double distanceFilter = 0,
  }) async {
    try {
      await _location.changeSettings(
        accuracy: accuracy,
        interval: interval,
        distanceFilter: distanceFilter,
      );
    } catch (e) {
      throw LocationException(e.toString());
    }
  }
} 