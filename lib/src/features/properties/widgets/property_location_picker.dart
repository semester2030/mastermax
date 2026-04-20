import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../../map/screens/location_picker_screen.dart';
import '../services/property_location_service.dart';

/// Widget لاختيار موقع العقار على الخريطة
///
/// يعرض Google Map مع إمكانية اختيار الموقع
/// يتبع الثيم الموحد للتطبيق
class PropertyLocationPicker extends StatefulWidget {
  final LatLng currentPosition;
  final ValueChanged<LatLng> onLocationChanged;
  final PropertyLocationService locationService;

  const PropertyLocationPicker({
    super.key,
    required this.currentPosition,
    required this.onLocationChanged,
    required this.locationService,
  });

  @override
  State<PropertyLocationPicker> createState() => _PropertyLocationPickerState();
}

class _PropertyLocationPickerState extends State<PropertyLocationPicker> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(24.7136, 46.6753);

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentPosition;
  }

  @override
  void didUpdateWidget(PropertyLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPosition != oldWidget.currentPosition) {
      _currentPosition = widget.currentPosition;
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition,
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await widget.locationService.getCurrentLocation();
      
      if (!mounted) return;
      
      setState(() {
        _currentPosition = location;
      });
      
      widget.onLocationChanged(location);
      
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: location,
              zoom: 15.0,
            ),
          ),
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديد موقعك الحالي بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحديد الموقع: $e'),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: AppColors.white,
            onPressed: _getCurrentLocation,
          ),
        ),
      );
    }
  }

  Future<void> _pickLocation() async {
    try {
      final selectedLocation = await Navigator.push<LatLng>(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialLocation: _currentPosition,
          ),
        ),
      );
      
      if (selectedLocation != null && mounted) {
        setState(() {
          _currentPosition = selectedLocation;
        });
        
        widget.onLocationChanged(selectedLocation);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديد الموقع بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحديد الموقع: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الموقع',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(AppColors.white, 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryLight),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                GoogleMap(
                  key: const ValueKey('propertyMap'),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    if (_currentPosition.latitude != 0 || _currentPosition.longitude != 0) {
                      controller.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: _currentPosition,
                            zoom: 15.0,
                          ),
                        ),
                      );
                    }
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 15.0,
                  ),
                  onTap: (LatLng position) {
                    setState(() {
                      _currentPosition = position;
                    });
                    widget.onLocationChanged(position);
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _currentPosition,
                      draggable: true,
                      onDragEnd: (LatLng newPosition) {
                        setState(() {
                          _currentPosition = newPosition;
                        });
                        widget.onLocationChanged(newPosition);
                      },
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'current_location',
                        onPressed: _getCurrentLocation,
                        backgroundColor: AppColors.primary,
                        mini: true,
                        child: const Icon(
                          Icons.my_location,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'pick_location',
                        onPressed: _pickLocation,
                        backgroundColor: AppColors.primary,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
