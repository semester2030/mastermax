import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show 
  MapWidget, 
  MapboxMap, 
  Point, 
  Position, 
  CameraOptions,
  MapboxStyles,
  PointAnnotationOptions,
  MapAnimationOptions,
  GestureListener,
  ScreenCoordinate;
import 'package:provider/provider.dart';
import '../providers/map_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../properties/models/property_model.dart';
import '../../cars/models/car_model.dart';
import '../../properties/providers/property_provider.dart';
import '../../cars/providers/car_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import './map_filter_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:like_button/like_button.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../../../core/utils/color_utils.dart';

/// ثوابت واجهة المستخدم
class UIConstants {
  static const double cardBorderRadius = 12.0;
  static const double iconSize = 20.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const double defaultPadding = 16.0;
  static const double defaultMargin = 8.0;
}

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({super.key});

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

  DateTime? _lastClickTime;

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
    });
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
      _showErrorMessage('حدث خطأ أثناء تحميل البيانات: $e');
    }
  }

  void _updateMapData(List<PropertyModel> properties, List<CarModel> cars) {
    if (!mounted) return;
    setState(() {
      _mapState.updateVisibleProperties();
      _mapState.updateVisibleCars(cars);
    });
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchPhoneCall(String? phone) async {
    if (phone?.isEmpty ?? true) {
      _showErrorMessage('رقم الهاتف غير متوفر');
      return;
    }

    final Uri url = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showErrorMessage('لا يمكن الاتصال بالرقم');
      }
    } catch (e) {
      _showErrorMessage('حدث خطأ أثناء محاولة الاتصال');
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;
        return Consumer2<CarProvider, PropertyProvider>(
          builder: (context, carProvider, propertyProvider, child) {
            if (carProvider.isLoading || propertyProvider.isLoading) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return Scaffold(
              body: Stack(
                children: [
                  SizedBox.expand(
                    child: MapWidget(
                      key: const ValueKey('mainMap'),
                      onMapCreated: _onMapCreated,
                      styleUri: MapboxStyles.MAPBOX_STREETS,
                      textureView: true,
                      cameraOptions: CameraOptions(
                        center: Point(
                          coordinates: Position(46.6753, 24.7136), // الرياض
                        ),
                        zoom: 12.0,
                      ),
                    ),
                  ),
                  _buildSearchBar(isPortrait),
                  _buildMapControls(isPortrait),
                  _buildListContainer(isPortrait),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onMapCreated(MapboxMap controller) async {
    try {
      await controller.style.setStyleURI(MapboxStyles.MAPBOX_STREETS);
      _mapState.setController(controller);
      _updateMapView3D(true);
      
      // إضافة تأخير قبل تحميل العلامات
      await Future.delayed(const Duration(seconds: 2));
      
      final defaultIcon = await _loadDefaultImage('assets/images/markers/property_marker.png');
      final pointAnnotationManager = await controller.annotations.createPointAnnotationManager();
      await pointAnnotationManager.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(46.6753, 24.7136)),
        image: defaultIcon,
        iconSize: 1.0,
      ));
      
      _updateMapMarkers();
      
      debugPrint('Successfully loaded default markers');
    } catch (e) {
      debugPrint('Error initializing map: $e');
    }
  }

  void _onMapTap(Point point) {
    try {
      final now = DateTime.now();
      final controller = _mapState.mapController;
      if (controller == null) return;
      
      if (_lastClickTime != null && 
          now.difference(_lastClickTime!) < const Duration(milliseconds: 300)) {
        // نقر مزدوج - تكبير الخريطة
        controller.flyTo(
          CameraOptions(
            center: point,
            zoom: 18.0,
            bearing: 0,
            pitch: 60,
          ),
          MapAnimationOptions(
            duration: 1000,
            startDelay: 0,
          ),
        );
      } else {
        // نقر مفرد - تحريك الخريطة
        _centerMapOnMarker(point);
      }
      _lastClickTime = now;
    } catch (e) {
      debugPrint('Error handling map tap: $e');
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
      ..color = ColorUtils.withOpacity(Colors.black, 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(
      const Offset(width / 2, height / 2),
      width / 2,
      shadowPaint,
    );

    // رسم الدائرة الخارجية
    final borderPaint = Paint()
      ..color = Colors.white
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
      ..color = Colors.white
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
        controller.setCamera(
          CameraOptions(
            pitch: enable ? 60.0 : 0.0,
            bearing: enable ? 45.0 : 0.0,
            zoom: enable ? 16.0 : 15.0,
          ),
        );
      }
    });
  }

  Widget _buildSearchBar(bool isPortrait) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.withOpacity(Colors.black, 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ColorUtils.withOpacity(AppColors.primary, 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن موقع...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                    onSubmitted: _handleSearch,
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: ColorUtils.withOpacity(Colors.grey, 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                GestureDetector(
                  onTap: () {
                    if (_selectedFilterType == MapFilterType.realEstate) {
                      _showPropertyFilters();
                    } else {
                      _showCarFilters();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ColorUtils.withOpacity(AppColors.primary, 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 30,
                  width: 1,
                  color: ColorUtils.withOpacity(Colors.grey, 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTypeButton(
                        isSelected: _selectedFilterType == MapFilterType.realEstate,
                        icon: Icons.home_work_outlined,
                        onTap: () => _onFilterTypeChanged(MapFilterType.realEstate),
                      ),
                      const SizedBox(width: 8),
                      _buildTypeButton(
                        isSelected: _selectedFilterType == MapFilterType.cars,
                        icon: Icons.directions_car_outlined,
                        onTap: () => _onFilterTypeChanged(MapFilterType.cars),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls(bool isPortrait) {
    return Positioned(
      bottom: isPortrait ? MediaQuery.of(context).size.height * 0.45 + 16 : 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: '3d',
            onPressed: () => _updateMapView3D(!_is3DMode),
            backgroundColor: AppColors.primary,
            child: Icon(
              _is3DMode ? Icons.view_in_ar : Icons.map,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListContainer(bool isPortrait) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: isPortrait ? MediaQuery.of(context).size.height * 0.45 : null,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Consumer<MapState>(
                builder: (context, mapState, _) {
                  if (_selectedFilterType == MapFilterType.realEstate) {
                    return ListView.builder(
                      itemCount: mapState.visibleProperties.length,
                      itemBuilder: (context, index) {
                        final property = mapState.visibleProperties[index];
                        return _buildPropertyListItem(property);
                      },
                    );
                  } else {
                    return ListView.builder(
                      itemCount: mapState.visibleCars.length,
                      itemBuilder: (context, index) {
                        final car = mapState.visibleCars[index];
                        return _buildCarListItem(car);
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyListItem(PropertyModel property) {
    return GestureDetector(
      onTap: () => _onPropertyTap(property),
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: property.images.first,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => ShimmerPlaceholder(
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
                const Positioned(
                  top: 8,
                  right: 8,
                  child: LikeButton(
                    circleColor: CircleColor(
                      start: Color(0xFFFF5722),
                      end: Color(0xFFE91E63),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '﷼ ${property.price}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.address,
                          style: TextStyle(color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarListItem(CarModel car) {
    return GestureDetector(
      onTap: () => _onCarTap(car),
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: car.images.first,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => ShimmerPlaceholder(
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
                const Positioned(
                  top: 8,
                  right: 8,
                  child: LikeButton(
                    circleColor: CircleColor(
                      start: Color(0xFFFF5722),
                      end: Color(0xFFE91E63),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '﷼ ${car.price}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          car.address,
                          style: TextStyle(color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey,
          size: 20,
        ),
      ),
    );
  }

  void _onFilterTypeChanged(MapFilterType type) {
    setState(() {
      _selectedFilterType = type;
      _mapState.setFilterType(type);
    });
  }

  void _showPropertyFilters() async {
    final result = await MapFilterScreen.show(
      context,
      isRealEstate: true,
    );
    if (result != null && mounted) {
      setState(() {
        // تحديث حالة الفلتر
      });
    }
  }

  void _showCarFilters() async {
    final result = await MapFilterScreen.show(
      context,
      isRealEstate: false,
    );
    if (result != null && mounted) {
      setState(() {
        // تحديث حالة الفلتر
      });
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
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _centerMapOnMarker(Point geometry) {
    final controller = _mapState.mapController;
    if (controller == null) return;
    
    controller.flyTo(
      CameraOptions(
        center: geometry,
        zoom: 16.0,
        bearing: 0,
        pitch: 60,
      ),
      MapAnimationOptions(
        duration: 1000,
        startDelay: 0,
      ),
    );
  }

  Future<void> _updateMapMarkers() async {
    final controller = _mapState.mapController;
    if (controller == null) {
      debugPrint('Map controller is null');
      return;
    }

    try {
      final pointAnnotationManager = await controller.annotations.createPointAnnotationManager();
      await pointAnnotationManager.deleteAll();

      if (_selectedFilterType == MapFilterType.realEstate) {
        debugPrint('Loading ${_mapState.visibleProperties.length} property markers');
        
        for (final property in _mapState.visibleProperties) {
          try {
            final location = property.location.coordinates;
            Uint8List markerIcon;
            
            if (property.images.isNotEmpty) {
              try {
                // تحميل الصورة من الأصول المحلية
                final ByteData data = await rootBundle.load(property.images.first);
                markerIcon = await _createCircularMarkerIcon(data.buffer.asUint8List());
              } catch (e) {
                debugPrint('Error loading image for property ${property.id}: $e');
                markerIcon = await _createSimpleMarkerIcon();
              }
            } else {
              debugPrint('No images available for property ${property.id}');
              markerIcon = await _createSimpleMarkerIcon();
            }
            
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
                textField: property.price.toString(),
                textSize: 12,
                textColor: Colors.white.toARGB32(),
                textHaloColor: Colors.black.toARGB32(),
                textHaloWidth: 1.0,
              ),
            );
            
            // إضافة تأخير صغير بين كل علامة
            await Future.delayed(const Duration(milliseconds: 100));
            
          } catch (e) {
            debugPrint('Error adding property marker: $e');
          }
        }
      } else {
        debugPrint('Loading ${_mapState.visibleCars.length} car markers');
        
        for (final car in _mapState.visibleCars) {
          try {
            final location = car.location;
            if (location == null) {
              debugPrint('No location available for car ${car.id}');
              continue;
            }
            
            Uint8List markerIcon;
            
            if (car.images.isNotEmpty) {
              try {
                final response = await http.get(Uri.parse(car.images.first));
                if (response.statusCode == 200) {
                  markerIcon = await _createCircularMarkerIcon(response.bodyBytes);
                } else {
                  debugPrint('Failed to load image for car ${car.id}: ${response.statusCode}');
                  markerIcon = await _createSimpleMarkerIcon();
                }
              } catch (e) {
                debugPrint('Error loading image for car ${car.id}: $e');
                markerIcon = await _createSimpleMarkerIcon();
              }
            } else {
              debugPrint('No images available for car ${car.id}');
              markerIcon = await _createSimpleMarkerIcon();
            }
            
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
                textField: car.price.toString(),
                textSize: 12,
                textColor: Colors.white.toARGB32(),
                textHaloColor: Colors.black.toARGB32(),
                textHaloWidth: 1.0,
              ),
            );
            
            // إضافة تأخير صغير بين كل علامة
            await Future.delayed(const Duration(milliseconds: 100));
            
          } catch (e) {
            debugPrint('Error adding car marker: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating map markers: $e');
    }
  }

  Future<Uint8List> _createCircularMarkerIcon(Uint8List imageBytes) async {
    try {
      final ui.Image originalImage = await decodeImageFromList(imageBytes);
      
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      const width = 100.0;
      const height = 100.0;

      // رسم الظل
      final shadowPaint = Paint()
        ..color = ColorUtils.withOpacity(Colors.black, 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(
        const Offset(width / 2, height / 2),
        width / 2,
        shadowPaint,
      );

      // رسم الإطار الخارجي
      final borderPaint = Paint()
        ..color = Colors.white
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
      debugPrint('Error creating circular marker icon: $e');
      return _createSimpleMarkerIcon();
    }
  }

  void _onPropertyTap(PropertyModel property) {
    final location = property.location.coordinates;
    
    _mapState.setSelectedProperty(property);
    _centerMapOnLocation(
      location.lng.toDouble(),
      location.lat.toDouble(),
    );
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPropertyDetailsSheet(property),
    );
  }

  void _onCarTap(CarModel car) {
    final location = car.location;
    if (location == null) return;
    
    _mapState.setSelectedCar(car);
    _centerMapOnLocation(
      location.longitude.toDouble(),
      location.latitude.toDouble(),
    );
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCarDetailsSheet(car),
    );
  }

  Widget _buildPropertyDetailsSheet(PropertyModel property) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صور العقار
                SizedBox(
                  height: 250,
                  child: PageView.builder(
                    itemCount: property.images.length,
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: property.images[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => ShimmerPlaceholder(
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '﷼ ${property.price}',
                        style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // تفاصيل العقار
                      _buildPropertyFeatures(property),
                      const SizedBox(height: 16),
                      // زر الاتصال
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchPhoneCall(property.contactPhone),
                          icon: const Icon(Icons.phone),
                          label: const Text('اتصال بالمالك'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCarDetailsSheet(CarModel car) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صور السيارة
                SizedBox(
                  height: 250,
                  child: PageView.builder(
                    itemCount: car.images.length,
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: car.images[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => ShimmerPlaceholder(
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '﷼ ${car.price}',
                        style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // تفاصيل السيارة
                      _buildCarFeatures(car),
                      const SizedBox(height: 16),
                      // زر الاتصال
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchPhoneCall(car.sellerPhone),
                          icon: const Icon(Icons.phone),
                          label: const Text('اتصال بالمالك'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _centerMapOnLocation(double longitude, double latitude) {
    final controller = _mapState.mapController;
    if (controller == null) return;
    
    controller.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: 16.0,
        bearing: 0,
        pitch: 60,
      ),
      MapAnimationOptions(
        duration: 1000,
        startDelay: 0,
      ),
    );
  }

  Widget _buildPropertyFeatures(PropertyModel property) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المميزات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeatureChip(
              icon: Icons.square_foot,
              label: '${property.area} م²',
            ),
            _buildFeatureChip(
              icon: Icons.king_bed,
              label: '${property.rooms} غرف',
            ),
            _buildFeatureChip(
              icon: Icons.bathtub,
              label: '${property.bathrooms} حمام',
            ),
            if (property.features['parking'] == true)
              _buildFeatureChip(
                icon: Icons.local_parking,
                label: 'موقف سيارات',
              ),
            if (property.features['pool'] == true)
              _buildFeatureChip(
                icon: Icons.pool,
                label: 'مسبح',
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCarFeatures(CarModel car) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المواصفات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeatureChip(
              icon: Icons.calendar_today,
              label: '${car.year}',
            ),
            _buildFeatureChip(
              icon: Icons.speed,
              label: '${car.kilometers} كم',
            ),
            _buildFeatureChip(
              icon: Icons.local_gas_station,
              label: car.fuelType,
            ),
            _buildFeatureChip(
              icon: Icons.settings,
              label: car.transmission,
            ),
            if (car.isVerified)
              _buildFeatureChip(
                icon: Icons.verified,
                label: 'موثق',
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(AppColors.primary, 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerPlaceholder extends StatelessWidget {
  final Widget child;

  const ShimmerPlaceholder({
    required this.child, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: child,
    );
  }
}
