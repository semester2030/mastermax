import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../services/custom_markers_service.dart';
import '../../cars/models/car_model.dart';
import '../../cars/screens/car_details_screen.dart';
import '../services/location_service.dart';
import '../services/directions_service.dart';
import '../widgets/glow_painter.dart';
import '../utils/map_helpers.dart';

/// شاشة كاملة لعرض تفاصيل السيارة
/// 
/// تعرض الصور في الأعلى (60%) والخريطة في الأسفل (40%)
/// مع إمكانية عرض المسافة من موقع المستخدم والسيارة
class CarFullScreenView extends StatefulWidget {
  final CarModel car;
  
  const CarFullScreenView({
    super.key,
    required this.car,
  });
  
  @override
  State<CarFullScreenView> createState() => _CarFullScreenViewState();
}

class _CarFullScreenViewState extends State<CarFullScreenView> {
  late PageController _pageController;
  int _currentImageIndex = 0;
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  Map<String, dynamic>? _distanceInfo;
  bool _isLoadingDistance = false;
  BitmapDescriptor? _carMapPin;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadCarMapPin();
    _getUserLocationAndDistance();
  }

  Future<void> _loadCarMapPin() async {
    if (widget.car.images.isEmpty) return;
    final icon = await CustomMarkersService.fromNetworkImageUrl(
      widget.car.images.first,
    );
    if (mounted) setState(() => _carMapPin = icon);
  }
  
  /// ✅ الحصول على موقع المستخدم وحساب المسافة
  Future<void> _getUserLocationAndDistance() async {
    final location = widget.car.location;
    if (location == null) return;
    
    try {
      setState(() => _isLoadingDistance = true);
      
      // ✅ الحصول على موقع المستخدم الحالي
      final locationService = LocationService();
      _userLocation = await locationService.getCurrentLocation();
      
      if (_userLocation != null) {
        final carLocation = LatLng(location.latitude.toDouble(), location.longitude.toDouble());
        
        // ✅ حساب المسافة والوقت من موقع المستخدم إلى السيارة
        final directionsService = DirectionsService();
        final routeInfo = await directionsService.getRouteInfo(
          origin: _userLocation!,
          destination: carLocation,
          mode: TravelMode.driving,
        );
        
        if (routeInfo != null) {
          setState(() {
            _distanceInfo = routeInfo;
            _isLoadingDistance = false;
          });
        } else {
          setState(() => _isLoadingDistance = false);
        }
      } else {
        setState(() => _isLoadingDistance = false);
      }
    } catch (e) {
      debugPrint('Error getting user location or distance: $e');
      setState(() => _isLoadingDistance = false);
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final location = widget.car.location;
    if (location == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل السيارة')),
        body: const Center(child: Text('لا يوجد موقع للسيارة')),
      );
    }
    
    final carLocation = LatLng(location.latitude.toDouble(), location.longitude.toDouble());
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ✅ الصور في الأعلى (60% من الشاشة)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildImageSection(),
          ),
          
          // ✅ زر الإغلاق في الأعلى
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          
          // ✅ مؤشر الصور
          if (widget.car.images.length > 1)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.6 - 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1} / ${widget.car.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          
          // ✅ الأزرار في أقصى اليمين في أسفل الصورة (بدون مربع أبيض)
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.4 + 16,
            right: 16,
            child: _buildCarActionButtons(),
          ),
          
          // ✅ الخريطة في الأسفل (40% من الشاشة) مع توهج
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: _buildMapSection(carLocation),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImageSection() {
    if (widget.car.images.isEmpty) {
      return Container(
        color: AppColors.primaryLight,
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 64, color: AppColors.textSecondary),
        ),
      );
    }
    
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.car.images.length,
      onPageChanged: (index) {
        setState(() {
          _currentImageIndex = index;
        });
      },
      itemBuilder: (context, index) {
        final imageUrl = widget.car.images[index];
        return Hero(
          tag: 'car_image_${widget.car.id}_$index',
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppColors.primaryLight,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppColors.primaryLight,
              child: const Icon(Icons.image_not_supported, size: 48, color: AppColors.textSecondary),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildMapSection(LatLng location) {
    return Stack(
      children: [
        // ✅ الخريطة مع 3D view
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: location,
            zoom: 17,
            tilt: 45.0, // ✅ 3D view (45 درجة)
            bearing: 0.0,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            // ✅ إضافة توهج بعد إنشاء الخريطة
            Future.delayed(const Duration(milliseconds: 500), () {
              _addGlowEffect(location);
            });
          },
          markers: {
            Marker(
              markerId: MarkerId('car_${widget.car.id}'),
              position: location,
              icon: _carMapPin ??
                  BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
              anchor: const Offset(0.5, 0.5),
            ),
            // ✅ إضافة marker لموقع المستخدم إذا كان متاحاً
            if (_userLocation != null)
              Marker(
                markerId: const MarkerId('user_location_car'),
                position: _userLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                anchor: const Offset(0.5, 0.5),
              ),
          },
          // ✅ رسم خط بين موقع المستخدم والسيارة
          polylines: _userLocation != null
              ? {
                  Polyline(
                    polylineId: const PolylineId('route_to_car'),
                    points: [_userLocation!, location],
                    color: AppColors.primary,
                    width: 3,
                    patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                  ),
                }
              : {},
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          mapType: MapType.normal,
        ),
        
        // ✅ توهج احترافي حول الموقع (في منتصف الخريطة)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: GlowPainter(
                center: Offset(
                  MediaQuery.of(context).size.width / 2,
                  MediaQuery.of(context).size.height * 0.4 / 2,
                ),
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        
        // ✅ معلومات المسافة والوقت في أعلى الخريطة
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _buildDistanceInfoCard(),
        ),
        
        // ✅ زر فتح في Google Maps في أسفل الخريطة
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: _buildGoogleMapsButton(location),
        ),
      ],
    );
  }
  
  /// ✅ بناء بطاقة معلومات المسافة والوقت
  Widget _buildDistanceInfoCard() {
    if (_isLoadingDistance) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'جاري حساب المسافة...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    
    if (_distanceInfo == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _distanceInfo!['distance_text'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                _distanceInfo!['duration_text'] ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// ✅ زر فتح في Google Maps
  Widget _buildGoogleMapsButton(LatLng location) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openInGoogleMaps(location, widget.car.address),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions, color: AppColors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'فتح في Google Maps',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// ✅ فتح الموقع في Google Maps
  Future<void> _openInGoogleMaps(LatLng location, String address) async {
    try {
      final lat = location.latitude;
      final lng = location.longitude;
      
      // ✅ رابط Google Maps للتنقل (directions)
      final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=${Uri.encodeComponent(address)}',
      );
      
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        final alternativeUrl = Uri.parse('https://maps.google.com/?q=$lat,$lng');
        if (await canLaunchUrl(alternativeUrl)) {
          await launchUrl(alternativeUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Error opening Google Maps: $e');
    }
  }
  
  void _addGlowEffect(LatLng location) {
    // ✅ تحريك الكاميرا قليلاً لإظهار التوهج بشكل أفضل مع 3D view
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 17.2,
          tilt: 45.0, // ✅ 3D view
          bearing: 0.0,
        ),
      ),
    );
  }
  
  /// ✅ بناء أزرار الإجراءات السريعة - أقصى اليمين في أسفل الصورة (بدون مربع أبيض)
  Widget _buildCarActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ✅ زر التفاصيل
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CarDetailsScreen(
                    carId: widget.car.id,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.9),
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_full,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'التفاصيل',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ✅ زر الاتصال
        Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.mediumImpact();
              MapHelpers.launchPhoneCall(widget.car.sellerPhone, context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone,
                    size: 18,
                    color: AppColors.white,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'اتصال',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
