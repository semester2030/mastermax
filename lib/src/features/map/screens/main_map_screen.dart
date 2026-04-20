import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/map_state.dart';
import '../models/map_marker.dart';
import '../widgets/property_full_screen_view.dart';
import '../widgets/car_full_screen_view.dart';
import '../widgets/map_controls.dart';
import '../widgets/list_container.dart';
import '../widgets/search_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../properties/models/property_model.dart';
import '../../properties/models/property_type.dart';
import '../../cars/models/car_model.dart';
import '../../properties/providers/property_provider.dart';
import '../../cars/providers/car_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import './map_filter_screen.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../../spotlight/models/video_model.dart';

class MainMapScreen extends StatefulWidget {
  final bool showBackButton; // ✅ إظهار زر الرجوع عند فتحها من Spotlight
  
  const MainMapScreen({
    super.key,
    this.showBackButton = false, // افتراضياً لا نعرض زر الرجوع (عند فتحها من MainScreen)
  });

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> {
  /// حالة الخريطة
  late MapState _mapState;
  
  /// نوع الفلتر المحدد
  MapFilterType _selectedFilterType = MapFilterType.realEstate;
  
  /// وضع العرض ثلاثي الأبعاد
  bool _is3DMode = true;
  
  /// تحكم في حقل البحث
  final TextEditingController _searchController = TextEditingController();
  
  /// حالة تهيئة البيانات
  bool _isInitialized = false;
  
  /// ✅ Markers للعرض على الخريطة
  final Set<Marker> _markers = {};

  // ✅ تم إزالة _lastClickTime لأنها غير مستخدمة حالياً

  // دالة لتحميل الصور من الإنترنت
  Future<Uint8List> loadImageFromNetwork(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      debugPrint('Failed to load image: ${response.statusCode}');
      return await _loadDefaultImage('assets/images/placeholder.png');
    } catch (e) {
      debugPrint('Error loading image: $e');
      return await _loadDefaultImage('assets/images/placeholder.png');
    }
  }

  @override
  void initState() {
    super.initState();
    _mapState = context.read<MapState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      // ✅ إذا كانت الخريطة مفتوحة من Spotlight، انتقل إلى موقع الفيديو
      if (widget.showBackButton) {
        _handleVideoLocation();
      }
    });
  }

  /// معالجة موقع الفيديو عند فتح الخريطة من Spotlight
  void _handleVideoLocation() {
    try {
      // جلب arguments من route
      final route = ModalRoute.of(context);
      if (route == null) return;
      
      final args = route.settings.arguments;
      if (args != null && args is Map && args.containsKey('selectedVideo')) {
        final video = args['selectedVideo'];
        if (video != null && video is VideoModel) {
          // الانتقال إلى موقع الفيديو بعد تأخير بسيط (لضمان تهيئة الخريطة)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            try {
              final location = video.location;
              _mapState.moveToLocation(
                location.longitude,
                location.latitude,
                animate: true,
              );
              debugPrint('✅ Moved map to video location: ${location.latitude}, ${location.longitude}');
            } catch (e) {
              debugPrint('Error moving to video location: $e');
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error handling video location: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_isInitialized) return;
    
    try {
      final propertyProvider = context.read<PropertyProvider>();
      final carProvider = context.read<CarProvider>();

      await Future.wait([
        propertyProvider.loadProperties(),
        carProvider.loadCars(),
      ]);

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      _updateMapData(propertyProvider.properties, carProvider.cars);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
      _showErrorMessage('حدث خطأ أثناء تحميل البيانات: $e');
    }
  }

  void _updateMapData(List<PropertyModel> properties, List<CarModel> cars) {
    if (!mounted) return;
    
    // ✅ تحديث العقارات في MapState
    _mapState.updateProperties(properties);
    
    // ✅ تحديث السيارات في MapState
    _mapState.updateVisibleCars(cars);
    
    debugPrint('✅ Updated map data: ${properties.length} properties, ${cars.length} cars');
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ✅ تم نقل _launchPhoneCall إلى MapHelpers.launchPhoneCall

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;
        return Consumer2<CarProvider, PropertyProvider>(
          builder: (context, carProvider, propertyProvider, child) {
            final firstLoadPending = !_isInitialized &&
                (carProvider.isLoading || propertyProvider.isLoading);

            return Scaffold(
              // ✅ إضافة AppBar مع زر رجوع عند فتحها من Spotlight
              appBar: widget.showBackButton
                  ? AppBar(
                      backgroundColor: AppColors.primary,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        tooltip: 'رجوع',
                      ),
                      title: const Text(
                        'الخريطة',
                        style: TextStyle(color: AppColors.white),
                      ),
                      elevation: 0,
                    )
                  : null,
              body: Stack(
                children: [
                  SizedBox.expand(
                    child: Consumer<MapState>(
                      builder: (context, mapState, child) {
                        // ✅ تحديث markers عند تغيير state
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _updateMarkers();
                        });
                        
                        return GoogleMap(
                          key: const ValueKey('mainMap'),
                          onMapCreated: _onMapCreated,
                          onTap: _onMapTap, // ✅ إضافة onTap لإغلاق bottom sheets
                          markers: _markers, // ✅ عرض markers على الخريطة
                          initialCameraPosition: const CameraPosition(
                            target: LatLng(24.7136, 46.6753), // الرياض (افتراضي - سيتم تحديثه تلقائياً)
                            zoom: 12.0,
                          ),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true, // تفعيل زر الموقع الحالي
                          mapType: MapType.normal,
                          onCameraMove: _mapState.onCameraMove,
                          onCameraIdle: () {
                            _mapState.updateMarkers();
                          },
                        );
                      },
                    ),
                  ),
                  if (firstLoadPending)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  MapSearchBar(
                    searchController: _searchController,
                    selectedFilterType: _selectedFilterType,
                    onSearch: _handleSearch,
                    onShowPropertyFilters: _showPropertyFilters,
                    onShowCarFilters: _showCarFilters,
                    onFilterTypeChanged: _onFilterTypeChanged,
                  ),
                  MapControls(
                    isPortrait: isPortrait,
                    is3DMode: _is3DMode,
                    onToggle3D: () => _updateMapView3D(!_is3DMode),
                  ),
                  ListContainer(
                    isPortrait: isPortrait,
                    selectedFilterType: _selectedFilterType,
                    onPropertyTap: _onPropertyTap,
                    onCarTap: _onCarTap,
                    onError: _showErrorMessage,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onMapCreated(GoogleMapController controller) async {
    try {
      _mapState.setController(controller);
      _updateMapView3D(true);
      _updateMapMarkers();
    } catch (e) {
      debugPrint('Error initializing map: $e');
    }
  }

  /// ✅ معالجة النقر على الخريطة الفارغة (ليس على marker)
  /// - إغلاق أي bottom sheet مفتوح
  /// - إزالة التحديد من marker محدد
  void _onMapTap(LatLng point) {
    if (!mounted) return;
    
    // ✅ إغلاق أي bottom sheet مفتوح (إذا كان هناك واحد)
    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // قد لا يكون هناك bottom sheet مفتوح
      debugPrint('No bottom sheet to close: $e');
    }
    
    // ✅ إزالة التحديد من marker محدد
    _mapState.setSelectedProperty(null);
    _mapState.setSelectedCar(null);
  }

  /// ✅ معالجة النقر على marker (الصورة الصغيرة في الخريطة)
  /// - البحث عن العقار/السيارة من marker ID
  /// - فتح PropertyFullScreenView أو CarFullScreenView
  void _onMarkerTap(MarkerId markerId) async {
    if (!mounted) return;
    
    try {
      final markerIdString = markerId.value;
      debugPrint('📍 Marker tapped: $markerIdString');
      
      // ✅ البحث عن العقار/السيارة من marker ID
      if (markerIdString.startsWith('selected_property_')) {
        // Marker محدد (من صورة العقار)
        final propertyId = markerIdString.replaceFirst('selected_property_', '');
        PropertyModel? property;
        try {
          property = _mapState.visibleProperties.firstWhere(
            (p) => p.id == propertyId,
          );
        } catch (e) {
          property = _mapState.selectedProperty;
        }
        if (property != null) {
          _onPropertyTap(property);
        }
      } else if (markerIdString.startsWith('selected_car_')) {
        // Marker محدد (من صورة السيارة)
        final carId = markerIdString.replaceFirst('selected_car_', '');
        CarModel? car;
        try {
          car = _mapState.visibleCars.firstWhere(
            (c) => c.id == carId,
          );
        } catch (e) {
          car = _mapState.selectedCar;
        }
        if (car != null) {
          _onCarTap(car);
        }
      } else {
        // ✅ Marker عادي من cluster
        // البحث في clusters
        for (final cluster in _mapState.clusters) {
          if (cluster.isCluster()) {
            // Cluster - لا نفتح شاشة، فقط نركز على الموقع
            if (cluster.id == markerIdString) {
              _centerMapOnLocation(
                cluster.position.longitude,
                cluster.position.latitude,
              );
              return;
            }
          } else if (cluster.markers.isNotEmpty) {
            // Marker فردي
            final marker = cluster.markers.firstWhere(
              (m) => m.id == markerIdString,
              orElse: () => cluster.markers.first,
            );
            
            if (marker.type == MarkerType.property) {
              // البحث عن العقار
              try {
                final property = _mapState.visibleProperties.firstWhere(
                  (p) => p.id == marker.id,
                );
                _onPropertyTap(property);
                return;
              } catch (e) {
                debugPrint('Property not found for marker: ${marker.id}');
              }
            } else if (marker.type == MarkerType.car) {
              // البحث عن السيارة
              try {
                final car = _mapState.visibleCars.firstWhere(
                  (c) => c.id == marker.id,
                );
                _onCarTap(car);
                return;
              } catch (e) {
                debugPrint('Car not found for marker: ${marker.id}');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling marker tap: $e');
    }
  }

  Future<Uint8List> _loadDefaultImage(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error loading default image: $e');
      // إنشاء صورة بسيطة كحل أخير
      return _createSimpleMarkerIcon();
    }
  }

  Future<Uint8List> _createSimpleMarkerIcon() async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const width = 100.0;
    const height = 100.0;
    
    // رسم الظل
    final shadowPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(
      const Offset(width / 2, height / 2),
      width / 2,
      shadowPaint,
    );

    // رسم الدائرة الخارجية
    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(
      const Offset(width / 2, height / 2),
      (width / 2) - 2,
      borderPaint,
    );

    // رسم الدائرة الداخلية
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      const Offset(width / 2, height / 2),
      (width / 2) - 4,
      paint,
    );

    // رسم أيقونة المنزل
    const iconSize = 40.0;
    final iconPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    const centerX = width / 2;
    const centerY = height / 2;
    
    // رسم شكل المنزل البسيط
    path.moveTo(centerX - iconSize / 2, centerY);
    path.lineTo(centerX, centerY - iconSize / 2);
    path.lineTo(centerX + iconSize / 2, centerY);
    path.lineTo(centerX + iconSize / 2, centerY + iconSize / 2);
    path.lineTo(centerX - iconSize / 2, centerY + iconSize / 2);
    path.close();

    canvas.drawPath(path, iconPaint);

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  void _updateMapView3D(bool enable) {
    setState(() {
      _is3DMode = enable;
      final controller = _mapState.mapController;
      if (controller != null) {
        controller.getVisibleRegion().then((bounds) {
          // التحقق من أن الـ controller لا يزال موجوداً
          final currentController = _mapState.mapController;
          if (currentController == null) return;
          
          final center = LatLng(
            (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
            (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
          );
          
          try {
            currentController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: center,
                tilt: enable ? 60.0 : 0.0,
                bearing: enable ? 45.0 : 0.0,
                zoom: enable ? 16.0 : 15.0,
              ),
            ),
          );
          } catch (e) {
            debugPrint('Error animating camera: $e');
          }
        }).catchError((e) {
          debugPrint('Error getting visible region: $e');
        });
      }
    });
  }

  // ✅ تم نقل _buildSearchBar إلى widgets/search_bar.dart

  // ✅ تم نقل _buildMapControls إلى widgets/map_controls.dart

  // ✅ تم نقل _buildListContainer إلى widgets/list_container.dart

  // ✅ تم نقل _buildOptimizedImage إلى widgets/optimized_image.dart

  // ✅ تم نقل _buildPropertyListItem إلى widgets/property_list_item.dart
  // ✅ تم نقل _buildCarListItem إلى widgets/car_list_item.dart

  // ✅ تم نقل _buildTypeButton إلى widgets/search_bar.dart

  void _onFilterTypeChanged(MapFilterType type) {
    _mapState.setFilterType(type);
    setState(() {
      _selectedFilterType = type;
    });
    _updateMarkers();
  }

  void _showPropertyFilters() async {
    final result = await MapFilterScreen.show(
      context,
      isRealEstate: true,
    );
    if (result != null && mounted) {
      await _applyPropertyFilters(result);
    }
  }
  
  /// ✅ تطبيق فلاتر العقارات على البيانات من Firestore
  Future<void> _applyPropertyFilters(Map<String, dynamic> filters) async {
    try {
      final propertyProvider = context.read<PropertyProvider>();
      
      // ✅ تحويل نوع العقار من النص إلى PropertyType
      PropertyType? propertyType;
      if (filters['propertyType'] != null) {
        final typeString = filters['propertyType'] as String;
        switch (typeString) {
          case 'شقة':
            propertyType = PropertyType.apartment;
            break;
          case 'فيلا':
            propertyType = PropertyType.villa;
            break;
          case 'أرض':
            propertyType = PropertyType.land;
            break;
          case 'محل تجاري':
            propertyType = PropertyType.commercial;
            break;
          default:
            propertyType = null;
        }
      }
      
      // ✅ استخراج نطاق السعر
      final priceRange = filters['priceRange'] as RangeValues?;
      final minPrice = priceRange?.start;
      final maxPrice = priceRange?.end;
      
      // ✅ استخراج نطاق المساحة
      final areaRange = filters['areaRange'] as RangeValues?;
      final minArea = areaRange?.start;
      final maxArea = areaRange?.end;
      
      // ✅ استخراج عدد الغرف
      final roomsRange = filters['roomsRange'] as RangeValues?;
      final minRooms = roomsRange?.start.round();
      
      // ✅ استخراج عدد الحمامات
      final bathroomsRange = filters['bathroomsRange'] as RangeValues?;
      final minBathrooms = bathroomsRange?.start.round();
      
      // ✅ استخراج المدينة
      final city = filters['city'] as String?;
      
      // ✅ استخراج نوع العرض (للبيع / للإيجار)
      final offerType = filters['offerType'] as OfferType?;
      
      // ✅ جلب العقارات المفلترة من Firestore
      final filteredProperties = await propertyProvider.service.getProperties(
        type: propertyType,
        minPrice: minPrice,
        maxPrice: maxPrice,
        minRooms: minRooms,
        location: city,
      );
      
      // ✅ تطبيق فلاتر إضافية محلياً (المميزات، إلخ)
      var finalProperties = filteredProperties;
      
      // ✅ فلترة حسب نوع العرض (للبيع / للإيجار)
      if (offerType != null) {
        finalProperties = finalProperties.where((p) => p.offerType == offerType).toList();
      }
      
      // فلترة حسب المميزات
      final amenities = filters['amenities'] as List<String>?;
      if (amenities != null && amenities.isNotEmpty) {
        finalProperties = finalProperties.where((property) {
          final propertyFeatures = property.features;
          return amenities.every((amenity) {
            // تحويل المميزة من النص إلى key في features
            switch (amenity) {
              case 'مكيف':
                return propertyFeatures['تكييف'] == true || propertyFeatures['تكييف مركزي'] == true;
              case 'مفروش':
                return propertyFeatures.containsKey('مفروش');
              case 'مطبخ':
                return propertyFeatures.containsKey('مطبخ');
              case 'مصعد':
                return propertyFeatures['مصعد'] == true;
              case 'حديقة':
                return propertyFeatures['حديقة'] == true;
              default:
                return propertyFeatures[amenity] == true;
            }
          });
        }).toList();
      }
      
      // ✅ فلترة حسب المميزات الإضافية
      if (filters['hasParking'] == true) {
        finalProperties = finalProperties.where((p) => p.features['موقف سيارات'] == true).toList();
      }
      if (filters['hasPool'] == true || filters['hasSwimmingPool'] == true) {
        finalProperties = finalProperties.where((p) => p.features['مسبح'] == true).toList();
      }
      if (filters['hasGarden'] == true) {
        finalProperties = finalProperties.where((p) => p.features['حديقة'] == true).toList();
      }
      
      // ✅ فلترة حسب المساحة
      if (minArea != null) {
        finalProperties = finalProperties.where((p) => p.area >= minArea).toList();
      }
      if (maxArea != null) {
        finalProperties = finalProperties.where((p) => p.area <= maxArea).toList();
      }
      
      // ✅ فلترة حسب عدد الحمامات
      if (minBathrooms != null) {
        finalProperties = finalProperties.where((p) => p.bathrooms >= minBathrooms).toList();
      }
      
      // ✅ فلترة حسب المميزات الإضافية الأخرى
      if (filters['hasElevator'] == true) {
        finalProperties = finalProperties.where((p) => p.features['مصعد'] == true).toList();
      }
      if (filters['hasSecurity'] == true) {
        finalProperties = finalProperties.where((p) => p.features['حراسة أمنية'] == true || p.features['أمن'] == true).toList();
      }
      
      // ✅ فلترة حسب المميزات الإضافية المتقدمة
      if (filters['hasRoofTop'] == true) {
        finalProperties = finalProperties.where((p) => p.features['سطح خاص'] == true || p.features['سطح'] == true).toList();
      }
      if (filters['hasGym'] == true) {
        finalProperties = finalProperties.where((p) => p.features['صالة رياضية'] == true || p.features['جيم'] == true).toList();
      }
      if (filters['hasStorage'] == true) {
        finalProperties = finalProperties.where((p) => p.features['غرفة تخزين'] == true || p.features['مستودع'] == true).toList();
      }
      if (filters['hasIntercom'] == true) {
        finalProperties = finalProperties.where((p) => p.features['انتركم'] == true || p.features['اتصال داخلي'] == true).toList();
      }
      if (filters['hasBasement'] == true) {
        finalProperties = finalProperties.where((p) => p.features['قبو'] == true || p.features['بدروم'] == true).toList();
      }
      if (filters['hasDriverRoom'] == true) {
        finalProperties = finalProperties.where((p) => p.features['غرفة سائق'] == true).toList();
      }
      if (filters['hasMaidRoom'] == true) {
        finalProperties = finalProperties.where((p) => p.features['غرفة خادمة'] == true).toList();
      }
      if (filters['hasCarEntrance'] == true) {
        finalProperties = finalProperties.where((p) => p.features['مدخل سيارة'] == true || p.features['موقف داخلي'] == true).toList();
      }
      if (filters['hasYard'] == true) {
        finalProperties = finalProperties.where((p) => p.features['حوش'] == true || p.features['فناء'] == true).toList();
      }
      if (filters['hasTent'] == true) {
        finalProperties = finalProperties.where((p) => p.features['خيمة'] == true || p.features['مظلة'] == true).toList();
      }
      if (filters['hasGuardRoom'] == true) {
        finalProperties = finalProperties.where((p) => p.features['غرفة حارس'] == true || p.features['غرفة أمن'] == true).toList();
      }
      if (filters['hasWellWater'] == true) {
        finalProperties = finalProperties.where((p) => p.features['بئر ماء'] == true || p.features['بئر'] == true).toList();
      }
      if (filters['hasAirConditioners'] == true) {
        finalProperties = finalProperties.where((p) => p.features['مكيفات'] == true || p.features['تكييف'] == true).toList();
      }
      if (filters['hasKitchenCabinets'] == true) {
        finalProperties = finalProperties.where((p) => p.features['مطبخ راكب'] == true || p.features['مطبخ مجهز'] == true).toList();
      }
      if (filters['hasCentralAC'] == true) {
        finalProperties = finalProperties.where((p) => p.features['تكييف مركزي'] == true).toList();
      }
      if (filters['hasGardenLighting'] == true) {
        finalProperties = finalProperties.where((p) => p.features['إضاءة حديقة'] == true || p.features['إضاءة خارجية'] == true).toList();
      }
      if (filters['hasElectricGate'] == true) {
        finalProperties = finalProperties.where((p) => p.features['بوابة كهربائية'] == true || p.features['بوابة أتوماتيك'] == true).toList();
      }
      if (filters['hasFireAlarm'] == true) {
        finalProperties = finalProperties.where((p) => p.features['نظام إنذار حريق'] == true || p.features['إنذار حريق'] == true).toList();
      }
      if (filters['hasSecurityCameras'] == true) {
        finalProperties = finalProperties.where((p) => p.features['كاميرات مراقبة'] == true || p.features['كاميرات'] == true).toList();
      }
      
      // ✅ فلترة حسب الخصائص الإضافية
      if (filters['isNegotiable'] == true) {
        finalProperties = finalProperties.where((p) => p.isNegotiable == true).toList();
      }
      if (filters['has360View'] == true) {
        finalProperties = finalProperties.where((p) => p.has360View == true).toList();
      }
      if (filters['hasVirtualTour'] == true) {
        finalProperties = finalProperties.where((p) => p.virtualTourUrl != null && p.virtualTourUrl!.isNotEmpty).toList();
      }
      
      // ✅ تحديث العقارات المرئية في الخريطة
      if (mounted) {
        _mapState.applyPropertyFilters(finalProperties);
        _showSuccessMessage('تم العثور على ${finalProperties.length} عقار');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('حدث خطأ أثناء تطبيق الفلاتر: $e');
      }
    }
  }

  void _showCarFilters() async {
    final result = await MapFilterScreen.show(
      context,
      isRealEstate: false,
    );
    if (result != null && mounted) {
      await _applyCarFilters(result);
    }
  }
  
  /// ✅ تطبيق فلاتر السيارات على البيانات من Firestore
  Future<void> _applyCarFilters(Map<String, dynamic> filters) async {
    try {
      final carProvider = context.read<CarProvider>();
      
      // ✅ جلب جميع السيارات من Firestore
      await carProvider.loadCars();
      var filteredCars = carProvider.cars;
      
      // ✅ فلترة حسب الماركة
      final carMake = filters['carMake'] as String?;
      if (carMake != null && carMake.isNotEmpty) {
        filteredCars = filteredCars.where((car) => car.brand == carMake).toList();
      }
      
      // ✅ فلترة حسب نوع السيارة (من خلال features)
      final carType = filters['carType'] as String?;
      if (carType != null && carType.isNotEmpty) {
        filteredCars = filteredCars.where((car) {
          // البحث في features أو model
          return car.features.contains(carType) || 
                 car.model.toLowerCase().contains(carType.toLowerCase());
        }).toList();
      }
      
      // ✅ فلترة حسب نطاق السعر
      final priceRange = filters['priceRange'] as RangeValues?;
      if (priceRange != null) {
        filteredCars = filteredCars.where((car) => 
          car.price >= priceRange.start && car.price <= priceRange.end
        ).toList();
      }
      
      // ✅ فلترة حسب نطاق السنة
      final yearRange = filters['yearRange'] as RangeValues?;
      if (yearRange != null) {
        filteredCars = filteredCars.where((car) => 
          car.year >= yearRange.start.round() && car.year <= yearRange.end.round()
        ).toList();
      }
      
      // ✅ فلترة حسب نطاق الكيلومترات
      final kmRange = filters['kmRange'] as RangeValues?;
      if (kmRange != null) {
        filteredCars = filteredCars.where((car) => 
          car.kilometers >= kmRange.start.round() && car.kilometers <= kmRange.end.round()
        ).toList();
      }
      
      // ✅ فلترة حسب نوع الوقود
      final fuelType = filters['fuelType'] as String?;
      if (fuelType != null && fuelType.isNotEmpty) {
        filteredCars = filteredCars.where((car) => car.fuelType == fuelType).toList();
      }
      
      // ✅ فلترة حسب نوع القير
      final transmission = filters['transmission'] as String?;
      if (transmission != null && transmission.isNotEmpty) {
        filteredCars = filteredCars.where((car) => car.transmission == transmission).toList();
      }
      
      // ✅ فلترة حسب المميزات
      final features = filters['features'] as List<String>?;
      if (features != null && features.isNotEmpty) {
        filteredCars = filteredCars.where((car) {
          return features.every((feature) => car.features.contains(feature));
        }).toList();
      }
      
      // ✅ فلترة حسب حالة السيارة
      final condition = filters['carCondition'] as String?;
      if (condition != null && condition.isNotEmpty) {
        filteredCars = filteredCars.where((car) {
          // مطابقة مرنة للحالة
          final carCondition = car.condition.toLowerCase();
          final filterCondition = condition.toLowerCase();
          return carCondition.contains(filterCondition) || 
                 filterCondition.contains(carCondition);
        }).toList();
      }
      
      // ✅ فلترة حسب اللون (من خلال features أو description)
      final color = filters['carColor'] as String?;
      if (color != null && color.isNotEmpty) {
        filteredCars = filteredCars.where((car) {
          return car.features.any((feature) => feature.toLowerCase().contains(color.toLowerCase())) ||
                 car.description.toLowerCase().contains(color.toLowerCase()) ||
                 car.title.toLowerCase().contains(color.toLowerCase());
        }).toList();
      }
      
      // ✅ فلترة حسب المميزات المتقدمة
      if (filters['isWarranty'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('ضمان') || car.features.contains('تحت الضمان')).toList();
      }
      if (filters['isInsurance'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('تأمين') || car.features.contains('مؤمن')).toList();
      }
      if (filters['hasPanoramicRoof'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('سقف بانورامي') || car.features.contains('فتحة سقف')).toList();
      }
      if (filters['has360Camera'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('كاميرا 360') || car.has360View == true).toList();
      }
      if (filters['hasHeadUpDisplay'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('شاشة عرض أمامية') || car.features.contains('HUD')).toList();
      }
      if (filters['hasWirelessCharging'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('شحن لاسلكي') || car.features.contains('wireless charging')).toList();
      }
      if (filters['hasRemoteStart'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('تشغيل عن بعد') || car.features.contains('remote start')).toList();
      }
      if (filters['hasVentilatedSeats'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('مقاعد مهواة') || car.features.contains('مقاعد مبردة')).toList();
      }
      if (filters['hasMemorySeats'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('مقاعد بذاكرة') || car.features.contains('memory seats')).toList();
      }
      if (filters['hasMassageSeats'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('مقاعد مساج') || car.features.contains('massage seats')).toList();
      }
      if (filters['hasThirdRow'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('صف ثالث') || car.features.contains('7 مقاعد') || car.features.contains('8 مقاعد')).toList();
      }
      if (filters['hasAdaptiveCruiseControl'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('مثبت سرعة ذكي') || car.features.contains('adaptive cruise')).toList();
      }
      if (filters['hasBlindSpotMonitoring'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('نظام مراقبة النقاط العمياء') || car.features.contains('blind spot')).toList();
      }
      if (filters['hasLaneAssist'] == true) {
        filteredCars = filteredCars.where((car) => car.features.contains('نظام المساعدة في الحارة') || car.features.contains('lane assist')).toList();
      }
      if (filters['has360View'] == true) {
        filteredCars = filteredCars.where((car) => car.has360View == true).toList();
      }
      if (filters['hasVirtualTour'] == true) {
        filteredCars = filteredCars.where((car) => car.virtualTourUrl != null && car.virtualTourUrl!.isNotEmpty).toList();
      }
      if (filters['hasInteriorView'] == true) {
        filteredCars = filteredCars.where((car) => car.hasInteriorView == true).toList();
      }
      
      // ✅ فلترة حسب bodyStyle, seatsCount, cylinders, trimLevel (من خلال features)
      final bodyStyle = filters['bodyStyle'] as String?;
      if (bodyStyle != null && bodyStyle.isNotEmpty) {
        filteredCars = filteredCars.where((car) => 
          car.features.any((f) => f.toLowerCase().contains(bodyStyle.toLowerCase()))
        ).toList();
      }
      
      final seatsCount = filters['seatsCount'] as String?;
      if (seatsCount != null && seatsCount.isNotEmpty) {
        filteredCars = filteredCars.where((car) => 
          car.features.any((f) => f.contains(seatsCount.replaceAll('مقاعد', '').trim()))
        ).toList();
      }
      
      final cylinders = filters['cylinders'] as String?;
      if (cylinders != null && cylinders.isNotEmpty) {
        filteredCars = filteredCars.where((car) => 
          car.features.any((f) => f.contains(cylinders.replaceAll('سلندر', '').trim()))
        ).toList();
      }
      
      // ✅ تحديث السيارات المرئية في الخريطة
      if (mounted) {
        _mapState.applyCarFilters(filteredCars);
        _showSuccessMessage('تم العثور على ${filteredCars.length} سيارة');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('حدث خطأ أثناء تطبيق الفلاتر: $e');
      }
    }
  }

  Future<void> _handleSearch(String value) async {
    if (value.isEmpty) return;
    
    try {
      if (_selectedFilterType == MapFilterType.realEstate) {
        final propertyProvider = context.read<PropertyProvider>();
        final properties = await propertyProvider.searchPropertiesByQuery(value);
        if (properties.isNotEmpty && mounted) {
          _mapState.updateVisibleProperties();
          _showSuccessMessage('تم العثور على ${properties.length} عقار');
        } else {
          _showErrorMessage('لم يتم العثور على عقارات');
        }
      } else {
        final carProvider = context.read<CarProvider>();
        final cars = await carProvider.searchCarsByQuery(value);
        if (cars.isNotEmpty && mounted) {
          _mapState.updateVisibleCars(cars);
          _showSuccessMessage('تم العثور على ${cars.length} سيارة');
        } else {
          _showErrorMessage('لم يتم العثور على سيارات');
        }
      }
    } catch (e) {
      _showErrorMessage('حدث خطأ أثناء البحث: $e');
    }
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ✅ تم إزالة _centerMapOnMarker لأنها غير مستخدمة (يتم استخدام _centerMapOnLocation بدلاً منها)

  /// ✅ تحديث markers على الخريطة (نفس منطق MapView)
  void _updateMarkers() {
    if (!mounted) return;
    
    setState(() {
      _markers.clear();
      
      final sel = _mapState.selectedMarker;
      if (sel != null) {
        final matchesFilter = (_mapState.filterType == MapFilterType.realEstate &&
                sel.type == MarkerType.property) ||
            (_mapState.filterType == MapFilterType.cars && sel.type == MarkerType.car);
        if (matchesFilter) {
          _markers.add(sel.toGoogleMarker(onTap: _onMarkerTap));
        }
      }
      
      // ✅ إضافة cluster markers (هذه هي الطريقة الصحيحة - markers تأتي من clusters)
      for (final cluster in _mapState.clusters) {
        if (cluster.isCluster()) {
          // ✅ Cluster يحتوي على عدة markers - عرض cluster marker
          _markers.add(
            Marker(
              markerId: MarkerId(cluster.id),
              position: cluster.position,
              infoWindow: InfoWindow(
                title: '${cluster.size} عنصر',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet,
              ),
              onTap: () => _onMarkerTap(MarkerId(cluster.id)),
            ),
          );
        } else if (cluster.markers.isNotEmpty) {
          // ✅ Cluster يحتوي على marker واحد - عرض marker الفردي
          for (final clusterMarker in cluster.markers) {
            // ✅ تجنب إضافة marker مكرر (إذا كان نفس ID كـ selectedMarker)
            if (_mapState.selectedMarker?.id != clusterMarker.id) {
              _markers.add(clusterMarker.toGoogleMarker(onTap: _onMarkerTap));
            }
          }
        }
      }
      
      debugPrint('✅ Updated ${_markers.length} markers on map');
      debugPrint('✅ Visible properties: ${_mapState.visibleProperties.length}');
      debugPrint('✅ Clusters: ${_mapState.clusters.length}');
    });
  }
  
  Future<void> _updateMapMarkers() async {
    // ✅ تم استبدالها بـ _updateMarkers() أعلاه
    _updateMarkers();
  }

  // ✅ تم إزالة _createCircularMarkerIcon لأنها غير مستخدمة (يتم استخدام _createCircularMarkerFromImage في map_state.dart)

  void _onPropertyTap(PropertyModel property) async {
    final location = property.location;
    
    _mapState.setSelectedProperty(property);
    
    // ✅ إنشاء marker مخصص من صورة العقار
    await _mapState.createSelectedPropertyMarker(property);
    
    _centerMapOnLocation(
      location.longitude,
      location.latitude,
    );
    
    if (!mounted) return;
    // ✅ فتح شاشة كاملة بدلاً من bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyFullScreenView(property: property),
        fullscreenDialog: true,
      ),
    );
  }

  void _onCarTap(CarModel car) async {
    final location = car.location;
    if (location == null) return;
    
    _mapState.setSelectedCar(car);
    
    // ✅ إنشاء marker مخصص من صورة السيارة
    await _mapState.createSelectedCarMarker(car);
    
    _centerMapOnLocation(
      location.longitude.toDouble(),
      location.latitude.toDouble(),
    );
    
    if (!mounted) return;
    // ✅ فتح شاشة كاملة بدلاً من bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarFullScreenView(car: car),
        fullscreenDialog: true,
      ),
    );
  }


  void _centerMapOnLocation(double longitude, double latitude) {
    final controller = _mapState.mapController;
    if (controller == null) return;
    
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: 16.0,
          bearing: 0,
          tilt: 60,
        ),
      ),
    );
  }

  // ✅ تم نقل جميع الدوال المساعدة إلى FeatureChips و MapHelpers
}

// ✅ تم نقل _PropertyFullScreenView إلى ملف منفصل: widgets/property_full_screen_view.dart
// ✅ تم نقل _CarFullScreenView إلى ملف منفصل: widgets/car_full_screen_view.dart

// ✅ تم نقل _PropertyDetailsSheetWidget إلى widgets/property_details_sheet.dart
// ✅ تم نقل _CarDetailsSheetWidget إلى widgets/car_details_sheet.dart

// ✅ تم نقل ShimmerPlaceholder إلى widgets/shimmer_placeholder.dart
