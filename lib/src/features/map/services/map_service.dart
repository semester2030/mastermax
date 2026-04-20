import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/theme/app_colors.dart';
import 'map_styles_service.dart';

class MapService {
  GoogleMapController? _mapController;
  bool _isInitialized = false;
  MapType _currentMapType = MapType.normal;
  String _currentStyleType = 'light';
  
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
      
      // تحذير فقط إذا لم يكن API Key موجوداً، لكن لا نوقف التطبيق
      if (AppConfig.mapApiKey.isEmpty || AppConfig.mapApiKey == 'YOUR_MAP_API_KEY') {
        debugPrint('⚠️ تحذير: Google Maps API Key غير مضبوط. بعض ميزات الخرائط قد لا تعمل.');
      }
      
      _isInitialized = true;
      debugPrint('تم تهيئة خدمة الخرائط بنجاح');
    } catch (e) {
      debugPrint('فشل في تهيئة خدمة الخرائط: $e');
      // لا نعيد throw الخطأ، نسمح للتطبيق بالعمل بدون خرائط
      _isInitialized = true; // نعتبره مهيأ حتى لو فشل
    }
  }

  /// تطبيق نمط الخريطة حسب النوع
  Future<void> applyStyleByType(String type) async {
    if (_mapController == null) return;
    
    try {
      final style = MapStylesService.getStyleByType(type);
      await _mapController!.setMapStyle(style);
      _currentStyleType = type;
      debugPrint('تم تطبيق نمط الخريطة: $type');
    } catch (e) {
      debugPrint('فشل في تطبيق نمط الخريطة: $e');
    }
  }

  /// تبديل نمط الخريطة بين العادي والقمر الصناعي
  Future<void> toggleMapStyle() async {
    if (_mapController == null) return;

    _currentMapType = _currentMapType == MapType.normal 
        ? MapType.satellite 
        : MapType.normal;

    debugPrint('تم تغيير نمط الخريطة إلى: ${_currentMapType == MapType.satellite ? "القمر الصناعي" : "العادي"}');
  }

  /// تبديل 3D View
  Future<void> toggle3DView({double? tilt}) async {
    if (_mapController == null) return;
    
    try {
      final currentPosition = await _mapController!.getVisibleRegion();
      final center = LatLng(
        (currentPosition.northeast.latitude + currentPosition.southwest.latitude) / 2,
        (currentPosition.northeast.longitude + currentPosition.southwest.longitude) / 2,
      );
      
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: center,
            tilt: tilt ?? 45.0,
            bearing: 0,
            zoom: await _mapController!.getZoomLevel(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('فشل في تبديل 3D View: $e');
    }
  }

  /// إنشاء widget الخريطة
  Widget createMap({
    required BuildContext context,
    CameraPosition? initialCameraPosition,
    void Function(GoogleMapController)? onMapCreated,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    Set<Polygon>? polygons,
    MapType? mapType,
    bool myLocationEnabled = true,
    bool myLocationButtonEnabled = false,
    bool zoomControlsEnabled = true,
    bool mapToolbarEnabled = false,
    String? styleType,
  }) {
    if (!_isInitialized) {
      debugPrint('محاولة تهيئة الخرائط...');
      initialize().catchError((error) {
        debugPrint('فشل في تهيئة الخريطة: $error');
      });
    }

    final defaultPosition = CameraPosition(
      target: LatLng(
        AppConfig.defaultLatitude,
        AppConfig.defaultLongitude,
      ),
      zoom: AppConfig.defaultZoom,
    );

    debugPrint('إنشاء عنصر الخريطة...');
    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.textSecondary),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) async {
                debugPrint('تم استدعاء onMapCreated...');
                _mapController = controller;
                
                // تطبيق النمط المخصص
                if (styleType != null) {
                  await applyStyleByType(styleType);
                }
                
                onMapCreated?.call(controller);
              },
              initialCameraPosition: initialCameraPosition ?? defaultPosition,
              markers: markers ?? {},
              polylines: polylines ?? {},
              polygons: polygons ?? {},
              mapType: mapType ?? _currentMapType,
              myLocationEnabled: myLocationEnabled,
              myLocationButtonEnabled: myLocationButtonEnabled,
              zoomControlsEnabled: zoomControlsEnabled,
              mapToolbarEnabled: mapToolbarEnabled,
            ),
          ),
        ),
        // زر تبديل نمط الخريطة
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.withOpacity(AppColors.textPrimary, 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: toggleMapStyle,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    _currentMapType == MapType.satellite ? Icons.map : Icons.satellite_alt,
                    color: AppColors.white,
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
    _mapController?.dispose();
    _mapController = null;
    _isInitialized = false;
  }

  /// الحصول على كائن التحكم بالخريطة
  GoogleMapController? get controller => _mapController;

  /// التحقق من حالة التهيئة
  bool get isInitialized => _isInitialized;
  
  /// الحصول على نوع الخريطة الحالي
  MapType get currentMapType => _currentMapType;
  
  /// الحصول على نوع النمط الحالي
  String get currentStyleType => _currentStyleType;
}
