import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/places_service.dart';
import '../../../core/theme/app_colors.dart';

class PlacesAutocompleteField extends StatefulWidget {
  final Function(LatLng location, String address)? onPlaceSelected;
  final String? hintText;
  final TextEditingController? controller;

  const PlacesAutocompleteField({
    super.key,
    this.onPlaceSelected,
    this.hintText,
    this.controller,
  });

  @override
  State<PlacesAutocompleteField> createState() => _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  final PlacesService _placesService = PlacesService();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _predictions = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onTextChanged(String value) async {
    if (value.isEmpty) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _placesService.autocomplete(input: value);
      setState(() {
        _predictions = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onPlaceSelected(Map<String, dynamic> prediction) async {
    _focusNode.unfocus();
    
    try {
      final details = await _placesService.getPlaceDetails(prediction['place_id']);
      if (details != null && widget.onPlaceSelected != null) {
        widget.onPlaceSelected!(
          details['location'] as LatLng,
          details['address'] as String,
        );
      }
    } catch (e) {
      // Handle error
    }

    setState(() {
      _predictions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: _onTextChanged,
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'ابحث عن مكان...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
        if (_predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                final structured = prediction['structured_formatting'];
                return ListTile(
                  leading: const Icon(Icons.place),
                  title: Text(structured['main_text'] ?? ''),
                  subtitle: Text(structured['secondary_text'] ?? ''),
                  onTap: () => _onPlaceSelected(prediction),
                );
              },
            ),
          ),
      ],
    );
  }
}

