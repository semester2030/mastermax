import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/car_model.dart';
import '../models/car_hotspot.dart';
import '../providers/car_provider.dart';
import '../widgets/car_specs_section.dart';
import '../../auth/providers/auth_state.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gallery_photo_view_wrapper.dart';

class CarDetailsScreen extends StatefulWidget {
  final String carId;

  const CarDetailsScreen({
    required this.carId, super.key,
  });

  @override
  State<CarDetailsScreen> createState() => _CarDetailsScreenState();
}

class _CarDetailsScreenState extends State<CarDetailsScreen> {
  late PageController _pageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CarProvider>().fetchCarById(widget.carId);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        title: const Text(
          'تفاصيل السيارة',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: custom_animations.AnimatedScale(
          duration: const Duration(milliseconds: 120),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Consumer<CarProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            );
          }

          final CarModel? car = provider.selectedCar;
          if (car == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: AppColors.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لم يتم العثور على السيارة',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildCarDetails(car);
        },
      ),
    );
  }

  Widget _buildCarDetails(CarModel car) {
    // المعرض خارج SingleChildScrollView حتى يعمل السحب الأفقي و PageView على الويب
    // دون أن يسرقه التمرير العمودي للصفحة.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImageGallery(car.images),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  car.title,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${car.price} ريال',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ✅ وصف السيارة - بطاقة واضحة وسهلة القراءة
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 40),
                    ),
                  ),
                  child: Text(
                    car.description,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      height: 1.6,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                CarSpecsSection(vehicle: car),
                const SizedBox(height: 24),
                if (car.features.isNotEmpty) ...[
                  const Text(
                    'المميزات',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: car.features.map((feature) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          feature,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 24),
                if (car.panoramaUrl != null || car.interiorPanoramaUrl != null || car.virtualTourUrl != null) ...[
                  const Text(
                    'عرض السيارة',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (car.panoramaUrl != null)
                        _buildViewButton(
                          icon: Icons.rotate_right,
                          label: 'عرض 360°',
                          onPressed: () => _show360View(car),
                        ),
                      if (car.interiorPanoramaUrl != null)
                        _buildViewButton(
                          icon: Icons.view_in_ar,
                          label: 'عرض داخلي',
                          onPressed: () => _showInteriorView(car),
                        ),
                      if (car.virtualTourUrl != null)
                        _buildViewButton(
                          icon: Icons.video_camera_front,
                          label: 'جولة افتراضية',
                          onPressed: () => _showVirtualTour(car),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
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
                          color: AppColors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              car.sellerName,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              car.sellerPhone,
                              style: TextStyle(
                                color: AppColors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ✅ قسم الموقع مع زر فتح في Google Maps
                _buildCarLocation(car),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ✅ بناء قسم موقع السيارة
  Widget _buildCarLocation(CarModel car) {
    // ✅ التحقق من وجود موقع
    if (car.location == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_off, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text(
              'الموقع غير متوفر',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final lat = car.location!.latitude;
    final lng = car.location!.longitude;
    final location = LatLng(lat, lng);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'الموقع',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            // ✅ زر فتح في Google Maps
            ElevatedButton.icon(
              onPressed: () => _openInGoogleMaps(location, car.address),
              icon: const Icon(Icons.directions, size: 20),
              label: const Text('فتح في Google Maps'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: location,
              zoom: 15.0,
            ),
            onMapCreated: (GoogleMapController controller) async {
              debugPrint('تم إنشاء خريطة السيارة بنجاح');
            },
            markers: {
              Marker(
                markerId: MarkerId(car.id),
                position: location,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
              ),
            },
          ),
        ),
        const SizedBox(height: 12),
        // ✅ بطاقة العنوان
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  car.address,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
      
      // ✅ محاولة فتح في تطبيق Google Maps
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // ✅ إذا فشل، جرب رابط بديل
        final alternativeUrl = Uri.parse(
          'https://maps.google.com/?q=$lat,$lng',
        );
        if (await canLaunchUrl(alternativeUrl)) {
          await launchUrl(
            alternativeUrl,
            mode: LaunchMode.externalApplication,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يمكن فتح Google Maps. يرجى التأكد من تثبيت التطبيق'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في فتح Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح Google Maps: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildImageGallery(List<String> images) {
    return Consumer<CarProvider>(
      builder: (context, provider, child) {
        final car = provider.selectedCar;
        if (car == null) {
          return const SizedBox.shrink();
        }

        final auth = context.watch<AuthState>();
        final uid = (auth.user?.id ?? '').trim();
        final sellerId = car.sellerId.trim();
        final canDeleteCarImages =
            auth.isAdmin || (uid.isNotEmpty && uid == sellerId);

        return SizedBox(
          height: 300,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                physics: const PageScrollPhysics(),
                itemCount: images.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Hero(
                    tag: 'car_image_${widget.carId}_$index',
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GalleryPhotoViewWrapper(
                              galleryItems: images,
                              initialIndex: index,
                              pageController: PageController(initialPage: index),
                            ),
                          ),
                        );
                      },
                      child: CachedNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.primaryLight,
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.primaryLight,
                          child: const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 50,
                          ),
                        ),
                        // تحسين الأداء
                        // ✅ إزالة memCacheWidth/memCacheHeight للحفاظ على الدقة الكاملة
                        // memCacheWidth: null,
                        // memCacheHeight: null,
                      ),
                    ),
                  );
                },
              ),
              if (images.length > 1)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Material(
                          color: AppColors.black.withOpacity(0.38),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            tooltip: 'الصورة السابقة',
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: _currentImageIndex > 0
                                  ? AppColors.white
                                  : AppColors.white.withOpacity(0.35),
                              size: 20,
                            ),
                            onPressed: _currentImageIndex > 0
                                ? () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                : null,
                          ),
                        ),
                        Material(
                          color: AppColors.black.withOpacity(0.38),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            tooltip: 'الصورة التالية',
                            icon: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: _currentImageIndex < images.length - 1
                                  ? AppColors.white
                                  : AppColors.white.withOpacity(0.35),
                              size: 20,
                            ),
                            onPressed: _currentImageIndex < images.length - 1
                                ? () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // ✅ عدّاد الصور الحاليّة / الإجمالي
              if (images.isNotEmpty)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  bottom: 16,
                  start: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          size: 16,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentImageIndex + 1} / ${images.length}',
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
              // حذف الصور: صاحب الإعلان أو الأدمن فقط (لا يظهر لزائر أو لمشاهد آخر)
              if (canDeleteCarImages && images.isNotEmpty)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  top: 16,
                  end: 16,
                  child: Material(
                    color: AppColors.black.withOpacity(0.4),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.white,
                        size: 22,
                      ),
                      tooltip: 'حذف هذه الصورة',
                      onPressed: () async {
                        if (images.length <= 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('لا يمكن حذف آخر صورة، يجب أن تبقى صورة واحدة على الأقل'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        final currentIndex = _currentImageIndex.clamp(0, images.length - 1);
                        final imageUrl = images[currentIndex];

                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('حذف الصورة'),
                              content: const Text('هل أنت متأكد من حذف هذه الصورة من صور السيارة؟'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('إلغاء'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('حذف'),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirm != true || !mounted) return;

                        try {
                          await context.read<CarProvider>().removeCarImage(
                                car: car,
                                imageUrl: imageUrl,
                              );

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حذف الصورة بنجاح'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل في حذف الصورة: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              // مؤشر الصور (قابل للنقر — مهم على الويب حيث السحب أقل شيوعاً)
              if (images.length > 1)
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: images.asMap().entries.map((entry) {
                      final active = _currentImageIndex == entry.key;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (entry.key == _currentImageIndex) return;
                          _pageController.animateToPage(
                            entry.key,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 10,
                          ),
                          child: Container(
                            width: active ? 10 : 8,
                            height: active ? 10 : 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.white.withOpacity(0.85),
                              border: Border.all(
                                color: AppColors.black.withOpacity(0.2),
                              ),
                            ),
                          ),
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
      color: AppColors.primary.withAlpha(230),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _show360View(CarModel car) {
    if (car.panoramaUrl != null) {
      final hotspots = [
        CarHotspot(
          id: '1',
          title: 'المحرك',
          description: 'محرك قوي وموفر للوقود',
          longitude: 0,
          latitude: 0,
          icon: Icons.directions_car,
          color: AppColors.primary,
          specificationKey: 'المحرك',
          specificationValue: '2.5 لتر، 4 سلندر',
        ),
        CarHotspot(
          id: '2',
          title: 'العجلات',
          description: 'عجلات رياضية مقاس 19 إنش',
          longitude: 90,
          latitude: -10,
          icon: Icons.tire_repair,
          color: AppColors.primary,
          specificationKey: 'العجلات',
          specificationValue: '19 إنش، رياضية',
        ),
        CarHotspot(
          id: '3',
          title: 'المصابيح الأمامية',
          description: 'مصابيح LED متكيفة',
          longitude: -90,
          latitude: -5,
          icon: Icons.highlight,
          color: AppColors.accent,
          specificationKey: 'المصابيح',
          specificationValue: 'LED متكيفة',
        ),
      ];

      Navigator.pushNamed(
        context,
        Routes.car360View,
        arguments: {
          'carId': car.id,
          'panoramaUrl': car.panoramaUrl!,
          'hotspots': hotspots,
          'isInterior': false,
        },
      );
    }
  }

  void _showInteriorView(CarModel car) {
    if (car.interiorPanoramaUrl != null) {
      final hotspots = [
        CarHotspot(
          id: '1',
          title: 'لوحة القيادة',
          description: 'شاشة لمس 12.3 إنش مع نظام ملاحة',
          longitude: 0,
          latitude: 0,
          icon: Icons.dashboard,
          color: AppColors.primary,
          specificationKey: 'الشاشة',
          specificationValue: '12.3 إنش تعمل باللمس',
          isInterior: true,
        ),
        CarHotspot(
          id: '2',
          title: 'المقاعد',
          description: 'مقاعد جلد مريحة مع تدفئة وتبريد',
          longitude: 90,
          latitude: -10,
          icon: Icons.event_seat,
          color: AppColors.primaryDark,
          specificationKey: 'المقاعد',
          specificationValue: 'جلد فاخر مع تدفئة وتبريد',
          isInterior: true,
        ),
        CarHotspot(
          id: '3',
          title: 'فتحة السقف',
          description: 'فتحة سقف بانورامية',
          longitude: -90,
          latitude: 45,
          icon: Icons.wb_sunny,
          color: AppColors.accent,
          specificationKey: 'السقف',
          specificationValue: 'بانورامي مع ستارة كهربائية',
          isInterior: true,
        ),
      ];

      Navigator.pushNamed(
        context,
        Routes.car360View,
        arguments: {
          'carId': car.id,
          'panoramaUrl': car.interiorPanoramaUrl!,
          'hotspots': hotspots,
          'isInterior': true,
        },
      );
    }
  }

  void _showVirtualTour(CarModel car) {
    if (car.virtualTourUrl != null) {
      Navigator.pushNamed(
        context,
        Routes.carVirtualTour,
        arguments: {
          'carId': car.id,
          'tourUrl': car.virtualTourUrl!,
        },
      );
    }
  }
} 