import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/utils/color_utils.dart';

class MapService {
  static const String mapboxAccessToken = 'pk.eyJ1IjoiZmF6MjAiLCJhIjoiY202czI0cWk5MDNxeTJqcHo1MnhpOWw4MSJ9.sxsMCAyMMqqLUf8xoVbLBg';
  MapboxMap? _mapController;
  bool _isInitialized = false;
  bool _isSatelliteView = false;
  
  // Singleton instance
  static final MapService _instance = MapService._internal();
  
  // Private constructor
  MapService._internal();
  
  // Factory constructor to return instance
  factory MapService() => _instance;

  /// تهيئة خدمة الخرائط
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('بدء تهيئة خدمة الخرائط...');
      
      if (mapboxAccessToken.isEmpty) {
        throw Exception('Mapbox access token is empty');
      }
      
      _isInitialized = true;
      debugPrint('تم تهيئة خدمة الخرائط بنجاح');
    } catch (e) {
      debugPrint('فشل في تهيئة خدمة الخرائط: $e');
      rethrow;
    }
  }

  /// تبديل نمط الخريطة بين العادي والقمر الصناعي
  Future<void> toggleMapStyle() async {
    if (_mapController == null) return;

    _isSatelliteView = !_isSatelliteView;
    final styleUri = _isSatelliteView
        ? "mapbox://styles/mapbox/satellite-v9" // نمط القمر الصناعي فقط
        : "mapbox://styles/mapbox/streets-v12"; // النمط العادي مع الشوارع

    try {
      await _mapController!.style.setStyleURI(styleUri);
      debugPrint('تم تغيير نمط الخريطة إلى: ${_isSatelliteView ? "القمر الصناعي" : "العادي"}');
    } catch (e) {
      debugPrint('فشل في تغيير نمط الخريطة: $e');
      _isSatelliteView = !_isSatelliteView; // إعادة القيمة لحالتها السابقة في حالة الفشل
    }
  }

  /// إنشاء widget الخريطة
  Widget createMap({
    required BuildContext context,
    CameraOptions? initialCameraPosition,
    void Function(MapboxMap)? onMapCreated,
  }) {
    if (!_isInitialized) {
      debugPrint('محاولة تهيئة الخرائط...');
      initialize().catchError((error) {
        debugPrint('فشل في تهيئة الخريطة: $error');
      });
    }

    final defaultPosition = Position(46.6753, 24.7136); // الرياض
    final defaultCameraOptions = CameraOptions(
      center: Point(coordinates: defaultPosition),
      zoom: 12.0,
    );

    debugPrint('إنشاء عنصر الخريطة...');
    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                MapWidget(
                  key: ValueKey('mapBox_${DateTime.now().millisecondsSinceEpoch}'),
                  onMapCreated: (MapboxMap controller) {
                    debugPrint('تم استدعاء onMapCreated...');
                    _mapController = controller;
                    
                    debugPrint('محاولة تعيين نمط الخريطة...');
                    controller.style.setStyleURI(_isSatelliteView
                        ? "mapbox://styles/mapbox/satellite-v9"
                        : "mapbox://styles/mapbox/streets-v12").then((_) {
                      debugPrint('تم تعيين نمط الخريطة بنجاح');
                      onMapCreated?.call(controller);
                    }).catchError((e) {
                      debugPrint('خطأ في تعيين نمط الخريطة: $e');
                    });
                  },
                  styleUri: _isSatelliteView
                      ? "mapbox://styles/mapbox/satellite-v9"
                      : "mapbox://styles/mapbox/streets-v12",
                  cameraOptions: initialCameraPosition ?? defaultCameraOptions,
                ),
                if (!_isInitialized)
                  Container(
                    color: ColorUtils.withOpacity(Colors.grey, 0.5),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // زر تبديل نمط الخريطة
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.withOpacity(Colors.black, 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: toggleMapStyle,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    _isSatelliteView ? Icons.map : Icons.satellite_alt,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// التخلص من موارد الخريطة
  void dispose() {
    debugPrint('تنظيف موارد الخريطة...');
    if (_mapController != null) {
      _mapController = null;
    }
    _isInitialized = false;
  }

  /// الحصول على كائن التحكم بالخريطة
  MapboxMap? get controller => _mapController;

  /// التحقق من حالة التهيئة
  bool get isInitialized => _isInitialized;
}
