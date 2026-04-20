import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../features/map/screens/location_picker_screen.dart';
import '../../../features/properties/services/property_location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class LocationPickerField extends StatefulWidget {
  final String label;
  final String initialAddress;
  final GeoPoint initialLocation;
  final Function(GeoPoint, String) onLocationSelected;

  const LocationPickerField({
    required this.label, required this.initialAddress, required this.initialLocation, required this.onLocationSelected, super.key,
  });

  @override
  State<LocationPickerField> createState() => LocationPickerFieldState();
}

class LocationPickerFieldState extends State<LocationPickerField> {
  late LatLng _selectedLocation;
  String _address = '';
  final _propertyLocationService = PropertyLocationService();

  @override
  void initState() {
    super.initState();
    // إذا كان الموقع (0, 0)، الحصول على الموقع الحالي تلقائياً
    if (widget.initialLocation.latitude == 0 && widget.initialLocation.longitude == 0) {
      _getCurrentLocation();
    } else {
      _selectedLocation = LatLng(
        widget.initialLocation.latitude,
        widget.initialLocation.longitude,
      );
      _address = widget.initialAddress;
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await _propertyLocationService.getCurrentLocation();
      final address = await _propertyLocationService.getAddressFromLocation(location);
      
      if (mounted) {
        setState(() {
          _selectedLocation = location;
          _address = address;
        });
        
        widget.onLocationSelected(
          GeoPoint(
            location.latitude,
            location.longitude,
          ),
          address,
        );
      }
    } catch (e) {
      debugPrint('فشل في الحصول على الموقع الحالي: $e');
      // استخدام الموقع الافتراضي (الرياض)
      if (mounted) {
        setState(() {
          _selectedLocation = const LatLng(24.7136, 46.6753);
          _address = 'الرياض، المملكة العربية السعودية';
        });
        
        widget.onLocationSelected(
          const GeoPoint(24.7136, 46.6753),
          'الرياض، المملكة العربية السعودية',
        );
      }
    }
  }

  Future<void> _openLocationPicker() async {
    try {
      final result = await Navigator.push<LatLng>(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialLocation: _selectedLocation,
          ),
        ),
      );

      if (result != null) {
        setState(() {
          _selectedLocation = result;
          _address = 'جاري الحصول على العنوان...';
        });

        // الحصول على العنوان الفعلي من الإحداثيات
        try {
          final address = await _propertyLocationService.getAddressFromLocation(result);
          if (mounted) {
            setState(() {
              _address = address;
            });
            
            widget.onLocationSelected(
              GeoPoint(
                result.latitude,
                result.longitude,
              ),
              address,
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _address = 'الموقع المحدد';
            });
            
            widget.onLocationSelected(
              GeoPoint(
                result.latitude,
                result.longitude,
              ),
              'الموقع المحدد',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error in location picker: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.brightGold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _openLocationPicker,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.withOpacity(AppTheme.brightGold, 0.3)),
              borderRadius: BorderRadius.circular(15),
              color: ColorUtils.withOpacity(AppTheme.royalPurple, 0.1),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppTheme.brightGold,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _address.isEmpty ? 'اختر الموقع' : _address,
                        style: const TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Icon(
                    Icons.edit_location_alt,
                    color: AppTheme.brightGold,
                    size: 20,
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