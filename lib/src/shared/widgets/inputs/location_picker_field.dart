import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../features/map/screens/location_picker_screen.dart';
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
  late Point _selectedLocation;
  String _address = '';

  @override
  void initState() {
    super.initState();
    _selectedLocation = Point(
      coordinates: Position(
        widget.initialLocation.longitude,
        widget.initialLocation.latitude,
      ),
    );
    _address = widget.initialAddress;
  }

  Future<void> _openLocationPicker() async {
    try {
      final result = await Navigator.push<Point>(
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
          _address = 'الموقع المحدد';
        });

        widget.onLocationSelected(
          GeoPoint(
            result.coordinates.lat.toDouble(),
            result.coordinates.lng.toDouble(),
          ),
          _address,
        );
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