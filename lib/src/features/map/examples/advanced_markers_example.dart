import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/custom_markers_service.dart';
import '../models/pin_config.dart';
import '../../../core/theme/app_colors.dart';

/// أمثلة على استخدام Advanced Markers
class AdvancedMarkersExample extends StatefulWidget {
  const AdvancedMarkersExample({super.key});

  @override
  State<AdvancedMarkersExample> createState() => _AdvancedMarkersExampleState();
}

class _AdvancedMarkersExampleState extends State<AdvancedMarkersExample> {
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    final markers = <Marker>{};

    // مثال 1: Marker عادي مع Glow
    final homeMarker = await CustomMarkersService.createMarkerIcon(
      PinConfig(
        color: AppColors.primary,
        icon: Icons.home,
        showGlow: true,
        size: 60,
      ),
    );
    markers.add(
      Marker(
        markerId: const MarkerId('home'),
        position: const LatLng(24.7136, 46.6753),
        icon: homeMarker,
        infoWindow: const InfoWindow(title: 'منزل'),
      ),
    );

    // مثال 2: Marker للسيارة
    final carMarker = await CustomMarkersService.createMarkerIcon(
      PinConfig(
        color: AppColors.success,
        icon: Icons.directions_car,
        showGlow: true,
        size: 60,
      ),
    );
    markers.add(
      Marker(
        markerId: const MarkerId('car'),
        position: const LatLng(24.7236, 46.6853),
        icon: carMarker,
        infoWindow: const InfoWindow(title: 'سيارة'),
      ),
    );

    // مثال 3: Marker للموقع
    final locationMarker = await CustomMarkersService.createMarkerIcon(
      PinConfig(
        color: AppColors.error,
        icon: Icons.location_on,
        showGlow: true,
        size: 60,
      ),
    );
    markers.add(
      Marker(
        markerId: const MarkerId('location'),
        position: const LatLng(24.7036, 46.6653),
        icon: locationMarker,
        infoWindow: const InfoWindow(title: 'موقع'),
      ),
    );

    setState(() {
      _markers.addAll(markers);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أمثلة Advanced Markers'),
        backgroundColor: AppColors.primary,
      ),
      body: GoogleMap(
        onMapCreated: (controller) {
          _mapController = controller;
        },
        initialCameraPosition: const CameraPosition(
          target: LatLng(24.7136, 46.6753),
          zoom: 13,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showMarkerOptions();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showMarkerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'إضافة Marker جديد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.home, color: AppColors.primary),
              title: const Text('منزل'),
              onTap: () => _addMarker(Icons.home, AppColors.primary, 'منزل'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car, color: AppColors.success),
              title: const Text('سيارة'),
              onTap: () => _addMarker(Icons.directions_car, AppColors.success, 'سيارة'),
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: AppColors.error),
              title: const Text('موقع'),
              onTap: () => _addMarker(Icons.location_on, AppColors.error, 'موقع'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMarker(IconData icon, Color color, String title) async {
    final marker = await CustomMarkersService.createMarkerIcon(
      PinConfig(
        color: color,
        icon: icon,
        showGlow: true,
        size: 60,
      ),
    );

    final newMarker = Marker(
      markerId: MarkerId(DateTime.now().millisecondsSinceEpoch.toString()),
      position: const LatLng(24.7136, 46.6753),
      icon: marker,
      infoWindow: InfoWindow(title: title),
    );

    setState(() {
      _markers.add(newMarker);
    });

    Navigator.pop(context);
  }
}


