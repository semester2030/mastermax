import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:io' show Platform;
import '../../../core/theme/app_colors.dart';

class LocationPickerScreen extends StatefulWidget {
  final Point? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  MapboxMap? _mapController;
  Point _selectedLocation = Point(
    coordinates: Position(46.6753, 24.7136),
  );
  final bool _isLoading = false;
  static const int _animationDuration = 2000;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
    }
  }

  void _onMapCreated(MapboxMap controller) {
    _mapController = controller;
    _moveToLocation(_selectedLocation);
  }

  Future<void> _moveToLocation(Point location) async {
    if (_mapController != null) {
      await _mapController!.flyTo(
        CameraOptions(
          center: location,
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: _animationDuration),
      );
    }
  }

  void _onMapClick(Point point) {
    setState(() {
      _selectedLocation = point;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر الموقع'),
        actions: [
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context, _selectedLocation);
                  },
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('تأكيد'),
          ),
        ],
      ),
      body: Platform.isWindows
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'خرائط Mapbox غير مدعومة على نظام Windows',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'الرجاء تجربة التطبيق على Android أو iOS',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                GestureDetector(
                  onTapUp: (details) {
                    if (_mapController != null) {
                      final screenPoint = Point(
                        coordinates: Position(
                          details.localPosition.dx,
                          details.localPosition.dy,
                        ),
                      );
                      _onMapClick(screenPoint);
                    }
                  },
                  child: MapWidget(
                    key: const ValueKey('locationPickerMap'),
                    onMapCreated: _onMapCreated,
                    styleUri: MapboxStyles.MAPBOX_STREETS,
                    cameraOptions: CameraOptions(
                      center: _selectedLocation,
                      zoom: 15.0,
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.location_pin,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ],
            ),
    );
  }
} 