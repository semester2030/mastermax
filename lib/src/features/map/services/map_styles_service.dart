import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapStylesService {
  /// الحصول على نمط الخريطة حسب النوع
  static String getStyleByType(String type) {
    switch (type) {
      case 'realEstate':
        return _realEstateStyle;
      case 'cars':
        return _carsStyle;
      case 'dark':
        return _darkStyle;
      case 'light':
      default:
        return _lightStyle;
    }
  }

  /// نمط العقارات
  static const String _realEstateStyle = '''
[
  {
    "featureType": "all",
    "elementType": "geometry",
    "stylers": [{"color": "#f5f5f5"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#c9c9c9"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  }
]
''';

  /// نمط السيارات
  static const String _carsStyle = '''
[
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#ffffff"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#dadada"}]
  }
]
''';

  /// النمط الداكن
  static const String _darkStyle = '''
[
  {
    "featureType": "all",
    "elementType": "geometry",
    "stylers": [{"color": "#242f3e"}]
  },
  {
    "featureType": "all",
    "elementType": "labels.text.stroke",
    "stylers": [{"lightness": -80}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#17263c"}]
  }
]
''';

  /// النمط الفاتح (افتراضي)
  static const String _lightStyle = '[]';
}

