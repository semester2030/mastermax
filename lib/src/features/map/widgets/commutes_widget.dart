import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/directions_service.dart';
import '../services/places_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../properties/models/property_model.dart';

/// Widget لعرض المسافات والأوقات من العقار إلى مواقع مختلفة
class CommutesWidget extends StatefulWidget {
  final PropertyModel property;
  final List<CommuteDestination> destinations;
  final TravelMode defaultTravelMode;

  const CommutesWidget({
    super.key,
    required this.property,
    this.destinations = const [],
    this.defaultTravelMode = TravelMode.driving,
  });

  @override
  State<CommutesWidget> createState() => _CommutesWidgetState();
}

class _CommutesWidgetState extends State<CommutesWidget> {
  final DirectionsService _directionsService = DirectionsService();
  final PlacesService _placesService = PlacesService();
  final Map<String, Map<String, dynamic>?> _routeInfo = {};
  final Map<String, bool> _isLoading = {};
  final Map<String, CommuteDestination> _actualDestinations = {};
  TravelMode _selectedMode = TravelMode.driving;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.defaultTravelMode;
    _loadCommutes();
  }

  Future<void> _loadCommutes() async {
    // ✅ إذا كانت هناك وجهات محددة مسبقاً، استخدمها مباشرة
    if (widget.destinations.isNotEmpty) {
      await _calculateRoutesForDestinations(widget.destinations);
      return;
    }

    // ✅ البحث عن أقرب أماكن حقيقية باستخدام PlacesService
    final destinations = await _findNearbyPlaces();
    
    // ✅ حساب المسافات والأوقات للأماكن الحقيقية
    await _calculateRoutesForDestinations(destinations);
  }

  /// ✅ البحث عن أقرب أماكن حقيقية من موقع العقار
  Future<List<CommuteDestination>> _findNearbyPlaces() async {
    final List<CommuteDestination> destinations = [];
    final propertyLocation = widget.property.location;
    
    // ✅ التحقق من صحة موقع العقار
    if (propertyLocation.latitude == 0.0 && propertyLocation.longitude == 0.0) {
      debugPrint('⚠️ موقع العقار غير صحيح (0,0)');
      return [];
    }

    try {
      // ✅ البحث عن أقرب مدرسة (مرتبة حسب المسافة)
      final schools = await _placesService.nearbySearch(
        location: propertyLocation,
        type: 'school',
        rankByDistance: true, // ✅ ترتيب حسب المسافة
      );
      
      if (schools.isNotEmpty) {
        final nearestSchool = schools.first; // ✅ الأقرب (بعد الترتيب)
        destinations.add(CommuteDestination(
          id: 'school',
          name: nearestSchool['name'] as String? ?? 'مدرسة قريبة',
          icon: Icons.school,
          location: nearestSchool['location'] as LatLng,
        ));
      }
      // ✅ إزالة Fallback - لا نضيف موقع افتراضي خاطئ
    } catch (e) {
      debugPrint('Error finding school: $e');
      // ✅ لا نضيف fallback - نتركه فارغاً بدلاً من معلومات خاطئة
    }

    try {
      // ✅ البحث عن أقرب مستشفى (مرتبة حسب المسافة)
      final hospitals = await _placesService.nearbySearch(
        location: propertyLocation,
        type: 'hospital',
        rankByDistance: true, // ✅ ترتيب حسب المسافة
      );
      
      if (hospitals.isNotEmpty) {
        final nearestHospital = hospitals.first; // ✅ الأقرب (بعد الترتيب)
        destinations.add(CommuteDestination(
          id: 'hospital',
          name: nearestHospital['name'] as String? ?? 'مستشفى قريب',
          icon: Icons.local_hospital,
          location: nearestHospital['location'] as LatLng,
        ));
      }
      // ✅ إزالة Fallback
    } catch (e) {
      debugPrint('Error finding hospital: $e');
    }

    try {
      // ✅ البحث عن أقرب مركز تجاري (مرتبة حسب المسافة)
      final malls = await _placesService.nearbySearch(
        location: propertyLocation,
        type: 'shopping_mall',
        rankByDistance: true, // ✅ ترتيب حسب المسافة
      );
      
      if (malls.isNotEmpty) {
        final nearestMall = malls.first; // ✅ الأقرب (بعد الترتيب)
        destinations.add(CommuteDestination(
          id: 'mall',
          name: nearestMall['name'] as String? ?? 'مركز تجاري',
          icon: Icons.shopping_cart,
          location: nearestMall['location'] as LatLng,
        ));
      }
      // ✅ إزالة Fallback
    } catch (e) {
      debugPrint('Error finding mall: $e');
    }

    try {
      // ✅ البحث عن أقرب مسجد (مرتبة حسب المسافة)
      final mosques = await _placesService.nearbySearch(
        location: propertyLocation,
        type: 'mosque',
        rankByDistance: true, // ✅ ترتيب حسب المسافة
      );
      
      if (mosques.isNotEmpty) {
        final nearestMosque = mosques.first; // ✅ الأقرب (بعد الترتيب)
        destinations.add(CommuteDestination(
          id: 'mosque',
          name: nearestMosque['name'] as String? ?? 'مسجد قريب',
          icon: Icons.place,
          location: nearestMosque['location'] as LatLng,
        ));
      }
    } catch (e) {
      debugPrint('Error finding mosque: $e');
    }

    try {
      // ✅ البحث عن أقرب صيدلية (مرتبة حسب المسافة)
      final pharmacies = await _placesService.nearbySearch(
        location: propertyLocation,
        type: 'pharmacy',
        rankByDistance: true, // ✅ ترتيب حسب المسافة
      );
      
      if (pharmacies.isNotEmpty) {
        final nearestPharmacy = pharmacies.first; // ✅ الأقرب (بعد الترتيب)
        destinations.add(CommuteDestination(
          id: 'pharmacy',
          name: nearestPharmacy['name'] as String? ?? 'صيدلية قريبة',
          icon: Icons.local_pharmacy,
          location: nearestPharmacy['location'] as LatLng,
        ));
      }
    } catch (e) {
      debugPrint('Error finding pharmacy: $e');
    }

    try {
      // ✅ البحث عن أقرب بنك (مرتبة حسب المسافة)
      final banks = await _placesService.nearbySearch(
        location: propertyLocation,
        type: 'bank',
        rankByDistance: true, // ✅ ترتيب حسب المسافة
      );
      
      if (banks.isNotEmpty) {
        final nearestBank = banks.first; // ✅ الأقرب (بعد الترتيب)
        destinations.add(CommuteDestination(
          id: 'bank',
          name: nearestBank['name'] as String? ?? 'بنك قريب',
          icon: Icons.account_balance,
          location: nearestBank['location'] as LatLng,
        ));
      }
    } catch (e) {
      debugPrint('Error finding bank: $e');
    }

    try {
      // ✅ البحث عن أقرب محطة وقود (مرتبة حسب المسافة)
      final gasStations = await _placesService.nearbySearch(
        location: propertyLocation,
        type: 'gas_station',
        rankByDistance: true, // ✅ ترتيب حسب المسافة
      );
      
      if (gasStations.isNotEmpty) {
        final nearestGasStation = gasStations.first; // ✅ الأقرب (بعد الترتيب)
        destinations.add(CommuteDestination(
          id: 'gas_station',
          name: nearestGasStation['name'] as String? ?? 'محطة وقود قريبة',
          icon: Icons.local_gas_station,
          location: nearestGasStation['location'] as LatLng,
        ));
      }
    } catch (e) {
      debugPrint('Error finding gas station: $e');
    }

    try {
      // ✅ البحث عن أقرب مطعم (مرتبة حسب المسافة)
      final restaurants = await _placesService.nearbySearch(
        location: propertyLocation,
        type: 'restaurant',
        rankByDistance: true, // ✅ ترتيب حسب المسافة
      );
      
      if (restaurants.isNotEmpty) {
        final nearestRestaurant = restaurants.first; // ✅ الأقرب (بعد الترتيب)
        destinations.add(CommuteDestination(
          id: 'restaurant',
          name: nearestRestaurant['name'] as String? ?? 'مطعم قريب',
          icon: Icons.restaurant,
          location: nearestRestaurant['location'] as LatLng,
        ));
      }
    } catch (e) {
      debugPrint('Error finding restaurant: $e');
    }

    try {
      // ✅ البحث عن أقرب حديقة (مرتبة حسب المسافة)
      final parks = await _placesService.nearbySearch(
        location: propertyLocation,
        type: 'park',
        rankByDistance: true, // ✅ ترتيب حسب المسافة
      );
      
      if (parks.isNotEmpty) {
        final nearestPark = parks.first; // ✅ الأقرب (بعد الترتيب)
        destinations.add(CommuteDestination(
          id: 'park',
          name: nearestPark['name'] as String? ?? 'حديقة قريبة',
          icon: Icons.park,
          location: nearestPark['location'] as LatLng,
        ));
      }
    } catch (e) {
      debugPrint('Error finding park: $e');
    }

    // ✅ إضافة مطار الملك خالد (موقع ثابت معروف)
    destinations.add(CommuteDestination(
      id: 'airport',
      name: 'مطار الملك خالد',
      icon: Icons.flight,
      location: const LatLng(24.9584, 46.6988),
    ));

    return destinations;
  }

  /// ✅ حساب المسافات والأوقات لجميع الوجهات
  Future<void> _calculateRoutesForDestinations(List<CommuteDestination> destinations) async {
    // ✅ التحقق من صحة موقع العقار
    final propertyLocation = widget.property.location;
    if (propertyLocation.latitude == 0.0 && propertyLocation.longitude == 0.0) {
      debugPrint('⚠️ موقع العقار غير صحيح - لا يمكن حساب المسافات');
      return;
    }
    
    for (final destination in destinations) {
      setState(() {
        _isLoading[destination.id] = true;
        _actualDestinations[destination.id] = destination;
      });

      try {
        // ✅ حساب المسافة والأوقات من موقع العقار الفعلي
        final routeInfo = await _directionsService.getRouteInfo(
          origin: propertyLocation, // ✅ موقع العقار الفعلي
          destination: destination.location, // ✅ موقع المكان الفعلي
          mode: _selectedMode,
        );

        // ✅ التحقق من صحة البيانات المستلمة
        if (routeInfo != null && routeInfo['distance'] != null) {
          setState(() {
            _routeInfo[destination.id] = routeInfo;
            _isLoading[destination.id] = false;
          });
        } else {
          debugPrint('⚠️ لم يتم الحصول على معلومات المسار لـ ${destination.name}');
          setState(() {
            _routeInfo[destination.id] = null;
            _isLoading[destination.id] = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading commute for ${destination.name}: $e');
        setState(() {
          _routeInfo[destination.id] = null;
          _isLoading[destination.id] = false;
        });
      }
    }
  }

  // ✅ تم إزالة Fallback locations - لا نعرض معلومات خاطئة للمستخدم

  String _getTravelModeName(TravelMode mode) {
    switch (mode) {
      case TravelMode.driving:
        return 'قيادة';
      case TravelMode.walking:
        return 'مشي';
      case TravelMode.bicycling:
        return 'دراجة';
      case TravelMode.transit:
        return 'مواصلات';
    }
  }

  IconData _getTravelModeIcon(TravelMode mode) {
    switch (mode) {
      case TravelMode.driving:
        return Icons.directions_car;
      case TravelMode.walking:
        return Icons.directions_walk;
      case TravelMode.bicycling:
        return Icons.directions_bike;
      case TravelMode.transit:
        return Icons.directions_transit;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ استخدام الوجهات الفعلية إذا كانت موجودة، وإلا استخدام الوجهات المحددة
    final destinations = _actualDestinations.isNotEmpty
        ? _actualDestinations.values.toList()
        : (widget.destinations.isNotEmpty
            ? widget.destinations
            : [
                // ✅ فقط المطار (موقع ثابت معروف) - لا نضيف مواقع افتراضية خاطئة
                CommuteDestination(
                  id: 'airport',
                  name: 'مطار الملك خالد',
                  icon: Icons.flight,
                  location: const LatLng(24.9584, 46.6988),
                ),
              ]);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.defaultShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'المسافات والأوقات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              // اختيار نمط السفر
              DropdownButton<TravelMode>(
                value: _selectedMode,
                items: TravelMode.values.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(_getTravelModeIcon(mode), size: 18),
                        const SizedBox(width: 8),
                        Text(_getTravelModeName(mode)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (mode) {
                  if (mode != null) {
                    setState(() {
                      _selectedMode = mode;
                    });
                    _loadCommutes();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...destinations.map((destination) {
            final routeInfo = _routeInfo[destination.id];
            final isLoading = _isLoading[destination.id] ?? false;

            return _buildDestinationCard(
              destination: destination,
              routeInfo: routeInfo,
              isLoading: isLoading,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDestinationCard({
    required CommuteDestination destination,
    Map<String, dynamic>? routeInfo,
    required bool isLoading,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              destination.icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                if (isLoading)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (routeInfo != null)
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        routeInfo['distance_text'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        routeInfo['duration_text'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'غير متوفر',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary.withValues(alpha: 128),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// نموذج الوجهة
class CommuteDestination {
  final String id;
  final String name;
  final IconData icon;
  final LatLng location;

  const CommuteDestination({
    required this.id,
    required this.name,
    required this.icon,
    required this.location,
  });
}


