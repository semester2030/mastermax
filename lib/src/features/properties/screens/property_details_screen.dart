import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/property_model.dart';
import '../models/panorama_hotspot.dart';
import '../providers/property_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/route_constants.dart';
import '../../../shared/widgets/gallery_photo_view_wrapper.dart';
import '../../../features/map/services/map_service.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final String propertyId;

  const PropertyDetailsScreen({
    required this.propertyId,
    super.key,
  });

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  final PageController _pageController = PageController();
  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ar');
  final MapService _mapService = MapService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PropertyProvider>().fetchPropertyById(widget.propertyId);
      _initializeMap();
    });
  }

  Future<void> _initializeMap() async {
    try {
      await _mapService.initialize();
    } catch (e) {
      debugPrint('خطأ في تهيئة الخريطة: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 179),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.accent,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'تفاصيل العقار',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 179),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.share,
                color: AppColors.accent,
                size: 20,
              ),
            ),
            onPressed: () {
              final property =
                  context.read<PropertyProvider>().selectedProperty;
              if (property != null) {
                HapticFeedback.mediumImpact();
                SharePlus.instance.share(
                  ShareParams(
                    text: 'شاهد هذا العقار الرائع!\n'
                        '${property.title}\n'
                        'السعر: ${_numberFormat.format(property.price)} ريال\n'
                        'العنوان: ${property.address}\n'
                        'للتواصل: ${property.contactPhone}\n\n'
                        'تم المشاركة من تطبيق Master Max',
                    subject: property.title,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<PropertyProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            );
          }

          final property = provider.selectedProperty;
          if (property == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_work_outlined,
                    size: 64,
                    color: AppColors.textPrimary.withValues(alpha: 128),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لم يتم العثور على العقار',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildImageGallery(property.images),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                property.title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_numberFormat.format(property.price)} ريال',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSpecsSection(property),
                        const SizedBox(height: 16),
                        const Text(
                          'الوصف',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          property.description,
                          style: TextStyle(
                            color: AppColors.textPrimary.withValues(alpha: 204),
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildContactCard(property),
                        const SizedBox(height: 24),
                        _buildPropertyLocation(property),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageGallery(List<String> images) {
    return Consumer<PropertyProvider>(
      builder: (context, provider, child) {
        final property = provider.selectedProperty;
        if (property == null) {
          return const SizedBox.shrink();
        }
        
        final PageController pageController = PageController();
        
        return SizedBox(
          height: 300,
          child: Stack(
            children: [
              PageView.builder(
                controller: pageController,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GalleryPhotoViewWrapper(
                            key: ValueKey('gallery_$index'),
                            galleryItems: images,
                            initialIndex: index,
                            pageController: PageController(initialPage: index),
                          ),
                        ),
                      );
                    },
                    child: Image.asset(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Error loading image: $error');
                        return Container(
                          color: Colors.grey[300],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 50,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'خطأ في تحميل الصورة',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: images.asMap().entries.map((entry) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pageController.hasClients &&
                                pageController.page?.round() == entry.key
                            ? AppColors.accent
                            : AppColors.surface,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: AppColors.primary.withValues(alpha: 230),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.white, size: 20),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _show360View(PropertyModel property) {
    if (property.panoramaUrl != null) {
      final hotspots = [
        const PanoramaHotspot(
          id: '1',
          title: 'المدخل الرئيسي',
          description: 'مدخل فخم مع بوابة أمنية وكاميرات مراقبة',
          longitude: 0,
          latitude: 0,
          icon: Icons.door_front_door,
          color: AppColors.primary,
        ),
        const PanoramaHotspot(
          id: '2',
          title: 'حمام السباحة',
          description: 'حمام سباحة خارجي مع منطقة استجمام',
          longitude: 90,
          latitude: -10,
          icon: Icons.pool,
          color: Colors.blue,
        ),
        const PanoramaHotspot(
          id: '3',
          title: 'الحديقة',
          description: 'حديقة واسعة مع مساحات خضراء ومنطقة شواء',
          longitude: -90,
          latitude: -5,
          icon: Icons.park,
          color: Colors.green,
        ),
      ];

      Navigator.pushNamed(
        context,
        Routes.property360View,
        arguments: {
          'propertyId': property.id,
          'panoramaUrl': property.panoramaUrl!,
          'hotspots': hotspots,
        },
      );
    }
  }

  void _showVirtualTour(PropertyModel property) {
    final tourUrl = property.virtualTourUrl;
    if (tourUrl != null) {
      Navigator.pushNamed(
        context,
        Routes.propertyVirtualTour,
        arguments: {
          'propertyId': property.id,
          'tourUrl': tourUrl,
        },
      );
    }
  }

  Widget _buildSpecsSection(PropertyModel property) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 77),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSpecItem(
              Icons.bed_outlined,
              '${property.rooms}',
              'غرف',
              onTap: () => _showSpecDetails(context, 'الغرف', [
                'غرفة نوم رئيسية',
                'غرفة نوم أطفال',
                'غرفة معيشة',
                'غرفة طعام',
              ]),
            ),
            VerticalDivider(
              color: AppColors.primary.withValues(alpha: 77),
              thickness: 1,
            ),
            _buildSpecItem(
              Icons.bathroom_outlined,
              '${property.bathrooms}',
              'حمامات',
              onTap: () => _showSpecDetails(context, 'الحمامات', [
                'حمام رئيسي',
                'حمام ضيوف',
                'حمام خدمة',
              ]),
            ),
            VerticalDivider(
              color: AppColors.primary.withValues(alpha: 77),
              thickness: 1,
            ),
            _buildSpecItem(
              Icons.square_foot_outlined,
              '${property.area}',
              'م²',
              onTap: () => _showSpecDetails(context, 'المساحة', [
                'مساحة البناء: ${property.area} م²',
                'مساحة الأرض: ${property.area * 1.2} م²',
                'مساحة الحديقة: ${property.area * 0.2} م²',
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String value, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 179),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpecDetails(
      BuildContext context, String title, List<String> details) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تفاصيل $title',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...details.map((detail) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(PropertyModel property) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.mediumImpact();
          final Uri url = Uri.parse('tel:${property.contactPhone}');
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يمكن الاتصال بالرقم'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 77),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.black,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.contactPhone,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.address,
                      style: TextStyle(
                        color: AppColors.textPrimary.withValues(alpha: 179),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyLocation(PropertyModel property) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الموقع',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (property.location.coordinates.lat != 0 && property.location.coordinates.lng != 0)
          SizedBox(
            height: 200,
            child: _mapService.createMap(
              context: context,
              initialCameraPosition: CameraOptions(
                center: Point(
                  coordinates: Position(
                    property.location.coordinates.lng,
                    property.location.coordinates.lat,
                  ),
                ),
                zoom: 15.0,
              ),
              onMapCreated: (MapboxMap controller) async {
                debugPrint('تم إنشاء الخريطة بنجاح');
                await controller.annotations.createPointAnnotationManager().then((manager) {
                  manager.create(PointAnnotationOptions(
                    geometry: Point(
                      coordinates: Position(
                        property.location.coordinates.lng,
                        property.location.coordinates.lat,
                      ),
                    ),
                    iconImage: 'assets/images/markers/property_marker.png',
                    iconSize: 0.5,
                  ));
                });
              },
            ),
          ),
      ],
    );
  }
}
