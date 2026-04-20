import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationModel {
  final LatLng coordinates;
  final String? address;
  final String? city;
  final String? country;
  final double? accuracy;

  LocationModel({
    required this.coordinates,
    this.address,
    this.city,
    this.country,
    this.accuracy,
  });

  double get latitude => coordinates.latitude;
  double get longitude => coordinates.longitude;

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'country': country,
      'accuracy': accuracy,
    };
  }

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      coordinates: LatLng(
        json['latitude']?.toDouble() ?? 0.0,
        json['longitude']?.toDouble() ?? 0.0,
      ),
      address: json['address'],
      city: json['city'],
      country: json['country'],
      accuracy: json['accuracy']?.toDouble(),
    );
  }

  LocationModel copyWith({
    LatLng? coordinates,
    String? address,
    String? city,
    String? country,
    double? accuracy,
  }) {
    return LocationModel(
      coordinates: coordinates ?? this.coordinates,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      accuracy: accuracy ?? this.accuracy,
    );
  }
}

