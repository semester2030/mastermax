import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../models/map_marker.dart';
import '../models/map_cluster.dart';
import '../services/location_service.dart';
import '../services/clustering_service.dart';
import '../services/custom_markers_service.dart';
import '../../properties/models/property_model.dart';
import '../../cars/models/car_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

enum MapFilterType {
  realEstate,
  cars,
}

enum MapStyle {
  light,
  satellite,
}

class MapState extends ChangeNotifier {
  final LocationService _locationService;
  final ClusteringService _clusteringService;
  GoogleMapController? _mapController;
  List<PropertyModel> _allProperties = [];
  List<PropertyModel> _visibleProperties = [];
  PropertyModel? _selectedProperty;
  final List<MapMarker> _markers = [];
  final List<MapCluster> _clusters = [];
  MapFilterType _filterType = MapFilterType.realEstate;
  MapStyle _currentStyle = MapStyle.light;
  double _currentZoom = 15.0;
  final bool _isLoading = false;
  
  // إضافة متغيرات جديدة لدعم عرض Zillow
  CarModel? _selectedCar;
  List<CarModel> _visibleCars = [];

  /// أيقونات دائرية من صور العقارات/السيارات (مفتاح = id العقار أو السيارة).
  final LinkedHashMap<String, BitmapDescriptor> _propertyPinCache = LinkedHashMap();
  final LinkedHashMap<String, BitmapDescriptor> _carPinCache = LinkedHashMap();
  static const int _maxMarkerIconCache = 90;
  bool _propertyPinPrefetchInFlight = false;
  bool _carPinPrefetchInFlight = false;

  // إعدادات الخريطة
  static const double _defaultZoom = 12.0;
  static const double _maxZoom = 20.0;
  static const double _minZoom = 3.0;
  
  // مواقع المدن الرئيسية
  static final CameraPosition riyadh = CameraPosition(
    target: LatLng(24.7136, 46.6753),
    zoom: _defaultZoom,
    bearing: 0,
    tilt: 45,
  );
  
  static final CameraPosition jeddah = CameraPosition(
    target: LatLng(21.5433, 39.1728),
    zoom: _defaultZoom,
    bearing: 0,
    tilt: 45,
  );
  
  static final CameraPosition makkah = CameraPosition(
    target: LatLng(21.3891, 39.8579),
    zoom: _defaultZoom,
    bearing: 0,
    tilt: 45,
  );

  MapState(this._locationService, this._clusteringService);

  // Getters
  GoogleMapController? get mapController => _mapController;
  List<PropertyModel> get visibleProperties => _visibleProperties;
  List<CarModel> get visibleCars => _visibleCars;
  PropertyModel? get selectedProperty => _selectedProperty;
  CarModel? get selectedCar => _selectedCar;
  
  // ✅ Marker مخصص للعقار/السيارة المحدد (يظهر الصورة على الخريطة)
  MapMarker? _selectedMarker;
  MapMarker? get selectedMarker => _selectedMarker;
  List<MapMarker> get markers => _markers;
  List<MapCluster> get clusters => _clusters;
  MapFilterType get filterType => _filterType;
  bool get isLoading => _isLoading;
  double get currentZoom => _currentZoom;

  void setController(GoogleMapController controller) {
    _mapController = controller;
    // تأجيل التهيئة لتجنب استدعاء setState أثناء build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  Future<void> _initializeMap() async {
    if (_mapController == null) return;
    
    debugPrint('Initializing map...');
    
    try {
      // محاولة الحصول على الموقع الحالي
      LatLng? currentLocation;
      try {
        currentLocation = await _locationService.getCurrentLocation();
        if (currentLocation != null) {
          debugPrint('Got current location: ${currentLocation.latitude}, ${currentLocation.longitude}');
        } else {
          debugPrint('Current location is null');
        }
      } catch (e) {
        debugPrint('Could not get current location: $e');
        // استخدام الموقع الافتراضي إذا فشل الحصول على الموقع الحالي
        currentLocation = null;
      }
      
      // استخدام الموقع الحالي إذا كان متاحاً، وإلا استخدام الموقع الافتراضي
      final initialPosition = currentLocation != null
          ? CameraPosition(
              target: currentLocation,
              zoom: _defaultZoom,
              bearing: 0,
              tilt: 45,
            )
          : riyadh;
      
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(initialPosition),
        );
        
        // تحميل البيانات الأولية
        updateProperties(_allProperties);
        
        await updateMarkers();
        debugPrint('Map initialization completed');
      }
    } catch (e) {
      debugPrint('Error initializing map: $e');
      // في حالة الخطأ، استخدم الموقع الافتراضي
      if (_mapController != null) {
        try {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(riyadh),
          );
        } catch (e2) {
          debugPrint('Error setting default location: $e2');
        }
      }
    }
  }

  void updateProperties(List<PropertyModel> properties) {
    final ids = properties.map((p) => p.id).toSet();
    _propertyPinCache.removeWhere((id, _) => !ids.contains(id));
    _allProperties = properties;
    updateVisibleProperties();
    _updateClusters();
    notifyListeners();
  }

  void updateVisibleProperties() {
    try {
      _visibleProperties = _allProperties.toList();
      _updateClusters();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating visible properties: $e');
    }
  }
  
  /// ✅ تطبيق فلاتر على العقارات المرئية
  void applyPropertyFilters(List<PropertyModel> filteredProperties) {
    try {
      _visibleProperties = filteredProperties;
      _updateClusters();
      notifyListeners();
      debugPrint('✅ Applied property filters: ${filteredProperties.length} properties');
    } catch (e) {
      debugPrint('❌ Error applying property filters: $e');
    }
  }
  
  /// ✅ تطبيق فلاتر على السيارات المرئية
  void applyCarFilters(List<CarModel> filteredCars) {
    try {
      _visibleCars = filteredCars;
      _updateClusters();
      notifyListeners();
      debugPrint('✅ Applied car filters: ${filteredCars.length} cars');
    } catch (e) {
      debugPrint('❌ Error applying car filters: $e');
    }
  }

  /// أثناء تحريك الكاميرا: تحديث التكبير من [position] فقط (خفيف — لا استدعاء async لكل إطار).
  void onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom.clamp(_minZoom, _maxZoom);
  }

  /// بعد توقف الكاميرة: مزامنة التكبير وإعادة تجميع العلامات.
  Future<void> updateMarkers() async {
    if (_mapController == null) {
      return;
    }

    try {
      if (_mapController == null) return;
      _currentZoom = await _mapController!.getZoomLevel();
      _currentZoom = _currentZoom.clamp(_minZoom, _maxZoom);
      _updateClusters();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating markers: $e');
      if (e.toString().contains('disposed')) {
        _mapController = null;
      }
    }
  }

  void _updateClusters() {
    try {
      if (_filterType == MapFilterType.realEstate) {
        if (_visibleProperties.isEmpty) {
          _clusters.clear();
          return;
        }
        
        final validProperties = _visibleProperties.where((p) => 
          p.location.latitude != 0 && 
          p.location.longitude != 0
        ).toList();
        
        _clusters.clear();
        _clusters.addAll(_clusteringService.createClusters(
          validProperties.map((p) => MapMarker(
            id: p.id,
            position: LatLng(
              p.location.latitude,
              p.location.longitude,
            ),
            title: p.title,
            subtitle: '﷼ ${p.price}',
            type: MarkerType.property,
            imageUrl: p.images.isNotEmpty ? p.images.first : null,
            icon: _propertyPinCache[p.id],
          )).toList(),
          _currentZoom,
        ));

        _updateMapMarkers();
        _maybeSchedulePropertyPinPrefetch(validProperties);
      } else {
        if (_visibleCars.isEmpty) {
          _clusters.clear();
          return;
        }
        
        final validCars = _visibleCars.where((c) => 
          c.location != null &&
          c.location!.longitude != 0 && 
          c.location!.latitude != 0
        ).toList();
        
        _clusters.clear();
        _clusters.addAll(_clusteringService.createClusters(
          validCars.map((c) => MapMarker(
            id: c.id,
            position: LatLng(
              c.location!.latitude.toDouble(),
              c.location!.longitude.toDouble(),
            ),
            title: c.title,
            subtitle: '﷼ ${c.price}',
            type: MarkerType.car,
            imageUrl: c.images.isNotEmpty ? c.images.first : null,
            icon: _carPinCache[c.id],
          )).toList(),
          _currentZoom,
        ));

        _updateMapMarkers();
        _maybeScheduleCarPinPrefetch(validCars);
      }
    } catch (e) {
      debugPrint('Error updating clusters: $e');
      _clusters.clear();
    }
  }

  void _evictOldestPins(LinkedHashMap<String, BitmapDescriptor> cache) {
    while (cache.length > _maxMarkerIconCache) {
      cache.remove(cache.keys.first);
    }
  }

  void _maybeSchedulePropertyPinPrefetch(List<PropertyModel> list) {
    if (_propertyPinPrefetchInFlight) return;
    final missing = list
        .where((p) =>
            p.id.isNotEmpty &&
            p.images.isNotEmpty &&
            !_propertyPinCache.containsKey(p.id))
        .take(40)
        .toList();
    if (missing.isEmpty) return;
    _propertyPinPrefetchInFlight = true;
    Future(() async {
      try {
        for (var round = 0; round < 12; round++) {
          final batch = list
              .where((p) =>
                  p.id.isNotEmpty &&
                  p.images.isNotEmpty &&
                  !_propertyPinCache.containsKey(p.id))
              .take(40)
              .toList();
          if (batch.isEmpty) break;
          for (final p in batch) {
            final icon = await CustomMarkersService.fromNetworkImageUrl(p.images.first);
            if (icon != null) {
              _propertyPinCache[p.id] = icon;
              _evictOldestPins(_propertyPinCache);
            }
          }
          if (_filterType != MapFilterType.realEstate) break;
          _updateClusters();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Property pin prefetch: $e');
      } finally {
        _propertyPinPrefetchInFlight = false;
      }
    });
  }

  void _maybeScheduleCarPinPrefetch(List<CarModel> list) {
    if (_carPinPrefetchInFlight) return;
    final missing = list
        .where((c) =>
            c.id.isNotEmpty &&
            c.images.isNotEmpty &&
            !_carPinCache.containsKey(c.id))
        .take(40)
        .toList();
    if (missing.isEmpty) return;
    _carPinPrefetchInFlight = true;
    Future(() async {
      try {
        for (var round = 0; round < 12; round++) {
          final batch = list
              .where((c) =>
                  c.id.isNotEmpty &&
                  c.images.isNotEmpty &&
                  !_carPinCache.containsKey(c.id))
              .take(40)
              .toList();
          if (batch.isEmpty) break;
          for (final c in batch) {
            final icon = await CustomMarkersService.fromNetworkImageUrl(c.images.first);
            if (icon != null) {
              _carPinCache[c.id] = icon;
              _evictOldestPins(_carPinCache);
            }
          }
          if (_filterType != MapFilterType.cars) break;
          _updateClusters();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Car pin prefetch: $e');
      } finally {
        _carPinPrefetchInFlight = false;
      }
    });
  }

  Future<void> _updateMapMarkers() async {
    try {
      // Markers are now handled by MapView widget
      // This method is kept for compatibility but doesn't need to do anything
      // as Google Maps handles markers through the markers set
      debugPrint('Markers updated through MapView widget');
    } catch (e) {
      debugPrint('Error updating map markers: $e');
    }
  }

  Future<Uint8List> _createSimpleMarkerIcon({bool isCarMarker = false}) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const width = 120.0;
    const height = 160.0;
    
    // رسم الظل للـ pin
    final shadowPaint = Paint()
      ..color = ColorUtils.withOpacity(AppColors.black, 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    final pinPath = Path();
    pinPath.moveTo(width / 2, height - 30);
    pinPath.lineTo(width / 2 - 15, height - 45);
    pinPath.quadraticBezierTo(width / 2, height, width / 2 + 15, height - 45);
    pinPath.close();
    canvas.drawPath(pinPath, shadowPaint);

    // رسم الدائرة الرئيسية
    final circlePaint = Paint()
      ..color = isCarMarker ? AppColors.success : AppColors.primary
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      const Offset(width / 2, height - 80),
      40,
      circlePaint,
    );

    // رسم حدود الدائرة
    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    
    canvas.drawCircle(
      const Offset(width / 2, height - 80),
      40,
      borderPaint,
    );

    // رسم الـ pin
    final pinPaint = Paint()
      ..color = isCarMarker ? AppColors.success : AppColors.primaryDark
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(pinPath, pinPaint);

    // إضافة أيقونة في الدائرة
    final iconPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (isCarMarker) {
      // رسم أيقونة السيارة
      canvas.drawRect(
        Rect.fromCenter(
          center: const Offset(width / 2, height - 80),
          width: 40,
          height: 25,
        ),
        iconPaint,
      );
      // إضافة العجلات
      canvas.drawCircle(const Offset(width / 2 - 15, height - 70), 5, iconPaint);
      canvas.drawCircle(const Offset(width / 2 + 15, height - 70), 5, iconPaint);
    } else {
      // رسم أيقونة المنزل
      final housePath = Path();
      housePath.moveTo(width / 2, height - 100);
      housePath.lineTo(width / 2 + 20, height - 70);
      housePath.lineTo(width / 2 + 20, height - 60);
      housePath.lineTo(width / 2 - 20, height - 60);
      housePath.lineTo(width / 2 - 20, height - 70);
      housePath.close();
      canvas.drawPath(housePath, iconPaint);
    }

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  void setSelectedProperty(PropertyModel? property) {
    if (_selectedProperty?.id != property?.id) {
      _selectedProperty = property;
      // ✅ إزالة الـ marker المحدد السابق
      _selectedMarker = null;
      notifyListeners();
    }
  }
  
  /// ✅ إنشاء marker مخصص من صورة العقار
  Future<void> createSelectedPropertyMarker(PropertyModel property) async {
    try {
      if (property.images.isEmpty) {
        _selectedMarker = null;
        notifyListeners();
        return;
      }
      
      final imageUrl = property.images.first;
      if (imageUrl.isEmpty) {
        _selectedMarker = null;
        notifyListeners();
        return;
      }
      
      // ✅ تحميل الصورة وإنشاء marker منها
      final imageBytes = await _loadImageFromUrl(imageUrl);
      if (imageBytes == null) {
        _selectedMarker = null;
        notifyListeners();
        return;
      }
      
      // ✅ إنشاء marker دائري من الصورة
      final markerIconBytes = await _createCircularMarkerFromImage(imageBytes);
      final markerIcon = BitmapDescriptor.fromBytes(markerIconBytes);
      
      _selectedMarker = MapMarker(
        id: 'selected_property_${property.id}',
        position: LatLng(
          property.location.latitude,
          property.location.longitude,
        ),
        title: property.title,
        subtitle: '﷼ ${property.price}',
        type: MarkerType.property,
        imageUrl: imageUrl,
        icon: markerIcon,
      );
      
      notifyListeners();
      debugPrint('✅ Created selected property marker with image');
    } catch (e) {
      debugPrint('❌ Error creating selected property marker: $e');
      _selectedMarker = null;
      notifyListeners();
    }
  }
  
  /// ✅ إنشاء marker مخصص من صورة السيارة
  Future<void> createSelectedCarMarker(CarModel car) async {
    try {
      if (car.images.isEmpty) {
        _selectedMarker = null;
        notifyListeners();
        return;
      }
      
      final imageUrl = car.images.first;
      if (imageUrl.isEmpty) {
        _selectedMarker = null;
        notifyListeners();
        return;
      }
      
      // ✅ تحميل الصورة وإنشاء marker منها
      final imageBytes = await _loadImageFromUrl(imageUrl);
      if (imageBytes == null) {
        _selectedMarker = null;
        notifyListeners();
        return;
      }
      
      // ✅ إنشاء marker دائري من الصورة
      final markerIconBytes = await _createCircularMarkerFromImage(imageBytes);
      final markerIcon = BitmapDescriptor.fromBytes(markerIconBytes);
      
      _selectedMarker = MapMarker(
        id: 'selected_car_${car.id}',
        position: LatLng(
          car.location!.latitude.toDouble(),
          car.location!.longitude.toDouble(),
        ),
        title: car.title,
        subtitle: '﷼ ${car.price}',
        type: MarkerType.car,
        imageUrl: imageUrl,
        icon: markerIcon,
      );
      
      notifyListeners();
      debugPrint('✅ Created selected car marker with image');
    } catch (e) {
      debugPrint('❌ Error creating selected car marker: $e');
      _selectedMarker = null;
      notifyListeners();
    }
  }
  
  /// ✅ تحميل الصورة من URL
  Future<Uint8List?> _loadImageFromUrl(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      debugPrint('❌ Failed to load image: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ Error loading image from URL: $e');
      return null;
    }
  }
  
  /// ✅ إنشاء marker دائري من الصورة
  Future<Uint8List> _createCircularMarkerFromImage(Uint8List imageBytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;
      
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      const width = 120.0;
      const height = 120.0;
      
      // رسم الظل
      final shadowPaint = Paint()
        ..color = ColorUtils.withOpacity(AppColors.black, 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(
        const Offset(width / 2, height / 2),
        width / 2,
        shadowPaint,
      );
      
      // رسم الإطار الخارجي
      final borderPaint = Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(
        const Offset(width / 2, height / 2),
        (width / 2) - 2,
        borderPaint,
      );
      
      // إنشاء مسار للقص
      final clipPath = Path()
        ..addOval(Rect.fromCircle(
          center: const Offset(width / 2, height / 2),
          radius: (width / 2) - 4,
        ));
      
      canvas.save();
      canvas.clipPath(clipPath);
      
      // حساب نسبة العرض إلى الارتفاع للصورة الأصلية
      final aspectRatio = originalImage.width / originalImage.height;
      
      // حساب أبعاد الصورة المناسبة للدائرة
      double targetWidth = width;
      double targetHeight = height;
      
      if (aspectRatio > 1) {
        targetWidth = height * aspectRatio;
        final offset = (targetWidth - width) / 2;
        canvas.drawImageRect(
          originalImage,
          Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
          Rect.fromLTWH(-offset, 0, targetWidth, height),
          Paint()..filterQuality = FilterQuality.high,
        );
      } else {
        targetHeight = width / aspectRatio;
        final offset = (targetHeight - height) / 2;
        canvas.drawImageRect(
          originalImage,
          Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
          Rect.fromLTWH(0, -offset, width, targetHeight),
          Paint()..filterQuality = FilterQuality.high,
        );
      }
      
      canvas.restore();
      
      final picture = pictureRecorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData!.buffer.asUint8List();
    } catch (e) {
      debugPrint('❌ Error creating circular marker from image: $e');
      return _createSimpleMarkerIcon();
    }
  }

  void setSelectedCar(CarModel? car) {
    try {
      if (_selectedCar?.id != car?.id) {
        _selectedCar = car;
        // ✅ إزالة الـ marker المحدد السابق
        _selectedMarker = null;
        if (car != null) {
          _filterType = MapFilterType.cars;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error setting selected car: $e');
    }
  }

  void updateVisibleCars(List<CarModel> cars) {
    try {
      if (_visibleCars != cars) {
        final ids = cars.map((c) => c.id).toSet();
        _carPinCache.removeWhere((id, _) => !ids.contains(id));
        _visibleCars = cars;
        _updateClusters();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating visible cars: $e');
    }
  }

  /// تغيير نوع العرض على الخريطة مع إزالة أي تحديد من النوع الآخر
  /// (وإلا يبقى ماركر/نافذة سيارة ظاهرة بعد اختيار العقارات والعكس).
  void setFilterType(MapFilterType type) {
    if (_filterType == type) return;
    _filterType = type;
    _selectedMarker = null;
    if (type == MapFilterType.realEstate) {
      _selectedCar = null;
    } else {
      _selectedProperty = null;
    }
    _updateClusters();
    notifyListeners();
  }

  Future<void> toggleMapStyle() async {
    _currentStyle = _currentStyle == MapStyle.light ? MapStyle.satellite : MapStyle.light;
    // Map style is handled by MapView widget
    notifyListeners();
  }

  Future<void> zoomIn() async {
    if (_mapController == null) return;
    final currentZoom = await _mapController!.getZoomLevel();
    if (currentZoom < _maxZoom) {
      await _mapController!.animateCamera(
        CameraUpdate.zoomIn(),
      );
    }
  }

  Future<void> zoomOut() async {
    if (_mapController == null) return;
    final currentZoom = await _mapController!.getZoomLevel();
    if (currentZoom > _minZoom) {
      await _mapController!.animateCamera(
        CameraUpdate.zoomOut(),
      );
    }
  }

  Future<void> centerToCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && _mapController != null) {
        await moveToLocation(
          position.longitude,
          position.latitude,
        );
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  Future<void> moveToLocation(double longitude, double latitude, {bool animate = true}) async {
    if (_mapController == null) return;

    try {
      final cameraPosition = CameraPosition(
        target: LatLng(latitude, longitude),
        zoom: _currentZoom,
      );

      if (_mapController == null) return;
      
      try {
        if (animate) {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(cameraPosition),
          );
        } else {
          await _mapController!.moveCamera(
            CameraUpdate.newCameraPosition(cameraPosition),
          );
        }
      } catch (e) {
        debugPrint('Error moving camera: $e');
      }
    } catch (e) {
      debugPrint('Error moving to location: $e');
    }
  }

  void updateZoom(double zoom) {
    _currentZoom = zoom;
    updateVisibleProperties();
    notifyListeners();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
