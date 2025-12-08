import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/map_marker.dart';
import '../models/map_cluster.dart';
import '../services/location_service.dart';
import '../services/clustering_service.dart';
import '../../properties/models/property_model.dart';
import '../../cars/models/car_model.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

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
  MapboxMap? _mapController;
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
  
  // إعدادات الخريطة
  static const double _defaultZoom = 12.0;
  static const double _maxZoom = 20.0;
  static const double _minZoom = 3.0;
  static const int _animationDuration = 2000;
  
  // مواقع المدن الرئيسية
  static final CameraOptions riyadh = CameraOptions(
    center: Point(coordinates: Position(46.6753, 24.7136)),
    zoom: _defaultZoom,
    bearing: 0,
    pitch: 45,
  );
  
  static final CameraOptions jeddah = CameraOptions(
    center: Point(coordinates: Position(39.1728, 21.5433)),
    zoom: _defaultZoom,
    bearing: 0,
    pitch: 45,
  );
  
  static final CameraOptions makkah = CameraOptions(
    center: Point(coordinates: Position(39.8579, 21.3891)),
    zoom: _defaultZoom,
    bearing: 0,
    pitch: 45,
  );

  MapState(this._locationService, this._clusteringService);

  // Getters
  MapboxMap? get mapController => _mapController;
  List<PropertyModel> get visibleProperties => _visibleProperties;
  List<CarModel> get visibleCars => _visibleCars;
  PropertyModel? get selectedProperty => _selectedProperty;
  List<MapMarker> get markers => _markers;
  List<MapCluster> get clusters => _clusters;
  MapFilterType get filterType => _filterType;
  bool get isLoading => _isLoading;
  double get currentZoom => _currentZoom;

  void setController(MapboxMap controller) {
    _mapController = controller;
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    if (_mapController == null) return;
    
    debugPrint('Initializing map...');
    
    try {
      if (kIsWeb) {
        // إعدادات خاصة للويب
        await _mapController!.setCamera(
          CameraOptions(
            center: riyadh.center,
            zoom: _defaultZoom,
            bearing: 0,
            pitch: 0, // تعطيل الميل في الويب لتحسين الأداء
          ),
        );
        
        // تعطيل بعض الميزات في الويب لتحسين الأداء
        await _mapController!.gestures.updateSettings(
          GesturesSettings(
            rotateEnabled: false,
            pitchEnabled: false,
            scrollEnabled: true,
            doubleTapToZoomInEnabled: true,
            doubleTouchToZoomOutEnabled: true,
            pinchToZoomEnabled: true,
          ),
        );
      } else {
        await _mapController!.setCamera(riyadh);
      }
      
      // تحميل البيانات الأولية
      updateProperties(_allProperties);
      
      await updateMarkers();
      debugPrint('Map initialization completed');
    } catch (e) {
      debugPrint('Error initializing map: $e');
      rethrow;
    }
  }

  void updateProperties(List<PropertyModel> properties) {
    _allProperties = properties;
    updateVisibleProperties();
    _updateClusters();
    notifyListeners();
  }

  void updateVisibleProperties() {
    try {
      _visibleProperties = _allProperties.toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating visible properties: $e');
    }
  }

  Future<void> onCameraMove() async {
    await updateMarkers();
  }

  Future<void> updateMarkers() async {
    if (_mapController == null) {
      debugPrint('Map controller is null');
      return;
    }

    debugPrint('Updating markers...');
    debugPrint('Visible properties: ${_visibleProperties.length}');
    debugPrint('All properties: ${_allProperties.length}');

    final camera = await _mapController!.getCameraState();
    _currentZoom = camera.zoom;
    _updateClusters();
    notifyListeners();
  }

  void _updateClusters() {
    try {
      if (_filterType == MapFilterType.realEstate) {
        if (_visibleProperties.isEmpty) {
          _clusters.clear();
          return;
        }
        
        final validProperties = _visibleProperties.where((p) => 
          p.location.coordinates.lat != 0 && 
          p.location.coordinates.lng != 0
        ).toList();
        
        _clusters.clear();
        _clusters.addAll(_clusteringService.createClusters(
          validProperties.map((p) => MapMarker(
            id: p.id,
            point: Point(coordinates: Position(
              p.location.coordinates.lng.toDouble(),
              p.location.coordinates.lat.toDouble(),
            )),
            title: p.title,
            subtitle: p.price != null ? '﷼ ${p.price}' : null,
            type: MarkerType.property,
            imageUrl: p.images.isNotEmpty ? p.images.first : null,
          )).toList(),
          _currentZoom,
        ));

        _updateMapMarkers();
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
            point: Point(coordinates: Position(
              c.location!.longitude.toDouble(),
              c.location!.latitude.toDouble(),
            )),
            title: c.title,
            subtitle: '﷼ ${c.price}',
            type: MarkerType.car,
            imageUrl: c.images.isNotEmpty ? c.images.first : null,
          )).toList(),
          _currentZoom,
        ));

        _updateMapMarkers();
      }
    } catch (e) {
      debugPrint('Error updating clusters: $e');
      _clusters.clear();
    }
  }

  Future<void> _updateMapMarkers() async {
    try {
      if (_mapController == null) {
        debugPrint('Map controller is null');
        return;
      }

      final pointAnnotationManager = await _mapController!.annotations.createPointAnnotationManager();
      await pointAnnotationManager.deleteAll();

      if (_filterType == MapFilterType.realEstate) {
        debugPrint('Loading ${_visibleProperties.length} property markers');
        
        for (final property in _visibleProperties) {
          try {
            final location = property.location.coordinates;
            final markerIcon = await _createSimpleMarkerIcon();
            
            await pointAnnotationManager.create(
              PointAnnotationOptions(
                geometry: Point(
                  coordinates: Position(
                    location.lng.toDouble(),
                    location.lat.toDouble(),
                  ),
                ),
                image: markerIcon,
                iconSize: 1.0,
                textField: '﷼ ${property.price}',
                textSize: 14,
                textColor: const Color(0xFF2C3E50).toARGB32(),
                textHaloColor: Colors.white.toARGB32(),
                textHaloWidth: 2.0,
                textOffset: [0, 2.5],
              ),
            );
          } catch (e) {
            debugPrint('Error adding property marker: $e');
          }
        }
      } else {
        debugPrint('Loading ${_visibleCars.length} car markers');
        
        for (final car in _visibleCars) {
          try {
            final location = car.location;
            if (location == null) {
              debugPrint('No location available for car ${car.id}');
              continue;
            }
            
            final markerIcon = await _createSimpleMarkerIcon(isCarMarker: true);
            
            await pointAnnotationManager.create(
              PointAnnotationOptions(
                geometry: Point(
                  coordinates: Position(
                    location.longitude.toDouble(),
                    location.latitude.toDouble(),
                  ),
                ),
                image: markerIcon,
                iconSize: 1.0,
                textField: '﷼ ${car.price}',
                textSize: 14,
                textColor: const Color(0xFF2C3E50).toARGB32(),
                textHaloColor: Colors.white.toARGB32(),
                textHaloWidth: 2.0,
                textOffset: [0, 2.5],
              ),
            );
          } catch (e) {
            debugPrint('Error adding car marker: $e');
          }
        }
      }
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
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    final pinPath = Path();
    pinPath.moveTo(width / 2, height - 30);
    pinPath.lineTo(width / 2 - 15, height - 45);
    pinPath.quadraticBezierTo(width / 2, height, width / 2 + 15, height - 45);
    pinPath.close();
    canvas.drawPath(pinPath, shadowPaint);

    // رسم الدائرة الرئيسية
    final circlePaint = Paint()
      ..color = isCarMarker ? const Color(0xFF2ECC71) : const Color(0xFF3498DB)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      const Offset(width / 2, height - 80),
      40,
      circlePaint,
    );

    // رسم حدود الدائرة
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    
    canvas.drawCircle(
      const Offset(width / 2, height - 80),
      40,
      borderPaint,
    );

    // رسم الـ pin
    final pinPaint = Paint()
      ..color = isCarMarker ? const Color(0xFF27AE60) : const Color(0xFF2980B9)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(pinPath, pinPaint);

    // إضافة أيقونة في الدائرة
    final iconPaint = Paint()
      ..color = Colors.white
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
      notifyListeners();
    }
  }

  void setSelectedCar(CarModel? car) {
    try {
      if (_selectedCar?.id != car?.id) {
        _selectedCar = car;
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
        _visibleCars = cars;
        _updateClusters();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating visible cars: $e');
    }
  }

  void setFilterType(MapFilterType type) {
    if (_filterType != type) {
      _filterType = type;
      _updateClusters();
      notifyListeners();
    }
  }

  Future<void> toggleMapStyle() async {
    _currentStyle = _currentStyle == MapStyle.light ? MapStyle.satellite : MapStyle.light;
    if (_mapController != null) {
      await _mapController!.loadStyleURI(
        _currentStyle == MapStyle.light ? MapboxStyles.MAPBOX_STREETS : MapboxStyles.SATELLITE,
      );
    }
    notifyListeners();
  }

  Future<void> zoomIn() async {
    if (_mapController == null) return;
    final camera = await _mapController!.getCameraState();
    if (camera.zoom < _maxZoom) {
      await _mapController!.setCamera(
        CameraOptions(zoom: camera.zoom + 1),
      );
    }
  }

  Future<void> zoomOut() async {
    if (_mapController == null) return;
    final camera = await _mapController!.getCameraState();
    if (camera.zoom > _minZoom) {
      await _mapController!.setCamera(
        CameraOptions(zoom: camera.zoom - 1),
      );
    }
  }

  Future<void> centerToCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && _mapController != null) {
        await moveToLocation(
          position.coordinates.lng.toDouble(),
          position.coordinates.lat.toDouble(),
        );
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  Future<void> moveToLocation(double longitude, double latitude, {bool animate = true}) async {
    if (_mapController == null) return;

    try {
      final cameraOptions = CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: _currentZoom,
      );

      if (animate) {
        await _mapController!.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: _animationDuration),
        );
      } else {
        await _mapController!.setCamera(cameraOptions);
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
