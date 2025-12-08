import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_model.dart';
import '../models/car_hotspot.dart';
import '../providers/car_provider.dart';
import '../widgets/car_specs_section.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/constants/route_constants.dart';
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CarProvider>().fetchCarById(widget.carId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'تفاصيل السيارة',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: custom_animations.AnimatedScale(
          duration: const Duration(milliseconds: 120),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: colorScheme.primary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Consumer<CarProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
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
                    color: colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لم يتم العثور على السيارة',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildCarDetails(car, colorScheme, textTheme);
        },
      ),
    );
  }

  Widget _buildCarDetails(CarModel car, ColorScheme colorScheme, TextTheme textTheme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImageGallery(car.images, colorScheme),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car.title,
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${car.price} ريال',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  car.description,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.primary.withOpacity(0.1),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                CarSpecsSection(vehicle: car),
                const SizedBox(height: 24),
                if (car.features.isNotEmpty) ...[
                  Text(
                    'المميزات',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
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
                          color: colorScheme.primary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          feature,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimary,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 24),
                if (car.panoramaUrl != null || car.interiorPanoramaUrl != null || car.virtualTourUrl != null) ...[
                  Text(
                    'عرض السيارة',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
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
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      if (car.interiorPanoramaUrl != null)
                        _buildViewButton(
                          icon: Icons.view_in_ar,
                          label: 'عرض داخلي',
                          onPressed: () => _showInteriorView(car),
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      if (car.virtualTourUrl != null)
                        _buildViewButton(
                          icon: Icons.video_camera_front,
                          label: 'جولة افتراضية',
                          onPressed: () => _showVirtualTour(car),
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: colorScheme.onPrimary,
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
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              car.sellerPhone,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onPrimary.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.phone_outlined,
                          color: colorScheme.onPrimary,
                          size: 24,
                        ),
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

  Widget _buildImageGallery(List<String> images, ColorScheme colorScheme) {
    return Consumer<CarProvider>(
      builder: (context, provider, child) {
        final car = provider.selectedCar;
        if (car == null) {
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
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 50,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              // مؤشر الصور
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
                            ? colorScheme.primary
                            : colorScheme.surface,
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
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Material(
      color: colorScheme.primary.withAlpha(230),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colorScheme.onPrimary),
              const SizedBox(width: 4),
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimary,
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
      final colorScheme = Theme.of(context).colorScheme;
      final hotspots = [
        CarHotspot(
          id: '1',
          title: 'المحرك',
          description: 'محرك قوي وموفر للوقود',
          longitude: 0,
          latitude: 0,
          icon: Icons.directions_car,
          color: colorScheme.primary,
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
          color: Colors.blue,
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
          color: Colors.amber,
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
      final colorScheme = Theme.of(context).colorScheme;
      final hotspots = [
        CarHotspot(
          id: '1',
          title: 'لوحة القيادة',
          description: 'شاشة لمس 12.3 إنش مع نظام ملاحة',
          longitude: 0,
          latitude: 0,
          icon: Icons.dashboard,
          color: colorScheme.primary,
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
          color: Colors.brown,
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
          color: Colors.orange,
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