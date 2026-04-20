import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/property_model.dart';
import '../providers/property_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import 'property_details_screen.dart';
import '../../map/providers/map_state.dart';
import '../../auth/providers/auth_state.dart';
import '../../auth/utils/listing_vertical_guard.dart';
import '../../../core/constants/route_constants.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  final _numberFormat = intl.NumberFormat('#,##0', 'ar');
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final propertyProvider = context.read<PropertyProvider>();
      final mapState = context.read<MapState>();
      
      // تحميل العقارات
      await propertyProvider.loadProperties();
      
      if (!mounted) return;

      // تحديث العقارات في MapState
      mapState.updateProperties(propertyProvider.properties);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _error = 'حدث خطأ أثناء تحميل العقارات: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<PropertyProvider, MapState, AuthState>(
      builder: (context, propertyProvider, mapState, authState, _) {
        final properties = mapState.visibleProperties.isNotEmpty 
            ? mapState.visibleProperties 
            : propertyProvider.properties;
        final t = authState.user?.type ?? authState.userType;
        final canAddProperty = ListingVerticalGuard.mayPublishProperties(
          t,
          isAdmin: authState.isAdmin,
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.transparent,
            elevation: 0,
            title: const Text(
              'العقارات',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list, color: AppColors.accent),
                onPressed: () {
                  // TODO: Implement filter
                },
              ),
            ],
          ),
          body: _buildBody(properties),
          floatingActionButton: canAddProperty
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.pushNamed(context, Routes.addProperty);
                  },
                  backgroundColor: AppColors.accent,
                  child: const Icon(Icons.add, color: AppColors.text),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody(List<PropertyModel> properties) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: ColorUtils.withOpacity(AppColors.primary, 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: ColorUtils.withOpacity(AppColors.textPrimary, 0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProperties,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (properties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_work_outlined,
              size: 64,
              color: ColorUtils.withOpacity(AppColors.accent, 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد عقارات متاحة',
              style: TextStyle(
                color: ColorUtils.withOpacity(AppColors.textLight, 0.7),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // ✅ تصفية العقارات بدون ID قبل العرض
    final validProperties = properties.where((p) => p.id.isNotEmpty).toList();
    
    if (validProperties.length != properties.length) {
      debugPrint('⚠️ Filtered out ${properties.length - validProperties.length} properties with empty IDs');
    }
    
    return RefreshIndicator(
      onRefresh: _loadProperties,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: validProperties.length,
        itemBuilder: (context, index) {
          final property = validProperties[index];
          return _buildPropertyCard(property);
        },
      ),
    );
  }

  Widget _buildPropertyCard(PropertyModel property) {
    return Material(
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          
          // ✅ التحقق من أن property.id غير فارغ
          if (property.id.isEmpty) {
            debugPrint('❌ Property ID is empty, cannot navigate to details');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('خطأ: معرف العقار غير صحيح'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          
          debugPrint('✅ Navigating to property details: ${property.id}');
          debugPrint('✅ Property title: ${property.title}');
          
          // تحديث الموقع في الخريطة
          final mapState = context.read<MapState>();
          mapState.setSelectedProperty(property);
          mapState.moveToLocation(
            property.location.longitude,
            property.location.latitude,
          );
        
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PropertyDetailsScreen(propertyId: property.id),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.withOpacity(AppColors.primary, 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: property.images.isEmpty
                          ? Container(
                              color: AppColors.surface,
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.accent,
                                  size: 48,
                                ),
                              ),
                            )
                          : PageView.builder(
                              itemCount: property.images.length,
                              itemBuilder: (context, index) {
                                final image = property.images[index];
                                return Hero(
                                  tag: 'property_image_${property.id}_$index',
                                  child: Container(
                                    color: AppColors.transparent,
                                    child: image.startsWith('http')
                                        ? CachedNetworkImage(
                                            imageUrl: image,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              color: AppColors.surface,
                                              child: const Center(
                                                child: CircularProgressIndicator(
                                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                                                ),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              color: AppColors.surface,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.error_outline,
                                                  color: AppColors.error,
                                                  size: 32,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Image.asset(
                                            image,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: AppColors.surface,
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.error_outline,
                                                    color: AppColors.error,
                                                    size: 32,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  // Loading indicator
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        color: ColorUtils.withOpacity(AppColors.black, 0.26),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.withOpacity(AppColors.textLight, 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.address,
                            style: TextStyle(color: ColorUtils.withOpacity(AppColors.textLight, 0.7)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildFeature(Icons.king_bed, '${property.rooms} غرف'),
                        _buildFeature(Icons.bathtub, '${property.bathrooms} حمام'),
                        _buildFeature(Icons.square_foot, '${_numberFormat.format(property.area)} م²'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'المميزات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: ColorUtils.withOpacity(AppColors.textLight, 0.7)),
        ),
      ],
    );
  }
} 