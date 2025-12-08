class MediaMetadata {
  final String deviceModel;
  final double latitude;
  final double longitude;
  final double? altitude;
  final String? locationName;
  final Map<String, dynamic> cameraSettings;
  final String watermarkInfo;
  final bool hasAudio;
  final String createdBy;
  final DateTime createdAt;

  MediaMetadata({
    required this.deviceModel,
    required this.latitude,
    required this.longitude,
    required this.cameraSettings, required this.watermarkInfo, required this.hasAudio, required this.createdBy, required this.createdAt, this.altitude,
    this.locationName,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceModel': deviceModel,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'locationName': locationName,
      'cameraSettings': cameraSettings,
      'watermarkInfo': watermarkInfo,
      'hasAudio': hasAudio,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MediaMetadata.fromJson(Map<String, dynamic> json) {
    return MediaMetadata(
      deviceModel: json['deviceModel'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      altitude: json['altitude'],
      locationName: json['locationName'],
      cameraSettings: json['cameraSettings'],
      watermarkInfo: json['watermarkInfo'],
      hasAudio: json['hasAudio'],
      createdBy: json['createdBy'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  MediaMetadata copyWith({
    String? deviceModel,
    double? latitude,
    double? longitude,
    double? altitude,
    String? locationName,
    Map<String, dynamic>? cameraSettings,
    String? watermarkInfo,
    bool? hasAudio,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return MediaMetadata(
      deviceModel: deviceModel ?? this.deviceModel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      locationName: locationName ?? this.locationName,
      cameraSettings: cameraSettings ?? this.cameraSettings,
      watermarkInfo: watermarkInfo ?? this.watermarkInfo,
      hasAudio: hasAudio ?? this.hasAudio,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 