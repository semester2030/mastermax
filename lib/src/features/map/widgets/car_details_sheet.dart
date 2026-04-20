import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../cars/models/car_model.dart';
import '../../cars/screens/car_details_screen.dart';
import 'feature_chips.dart';
import '../utils/map_helpers.dart';

/// Widget لعرض تفاصيل السيارة في Bottom Sheet
///
/// يعرض صور السيارة، العنوان، السعر، المواصفات، وأزرار الاتصال
/// يتبع الثيم الموحد للتطبيق
class CarDetailsSheet extends StatefulWidget {
  final CarModel car;
  
  const CarDetailsSheet({
    super.key,
    required this.car,
  });
  
  @override
  State<CarDetailsSheet> createState() => _CarDetailsSheetState();
}

class _CarDetailsSheetState extends State<CarDetailsSheet> {
  late PageController _pageController;
  int _currentImageIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.4, 0.75, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle للسحب
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // صور السيارة
                      SizedBox(
                        height: 350,
                        child: widget.car.images.isEmpty
                            ? Container(
                                color: AppColors.background,
                                child: const Center(
                                  child: Icon(Icons.image_not_supported, size: 64, color: AppColors.textSecondary),
                                ),
                              )
                            : Stack(
                                children: [
                                  PageView.builder(
                                    controller: _pageController,
                                    itemCount: widget.car.images.length,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentImageIndex = index;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      final imageUrl = widget.car.images[index];
                                      if (imageUrl.isEmpty) {
                                        return Container(
                                          color: AppColors.background,
                                          child: const Center(
                                            child: Icon(Icons.image_not_supported, size: 48, color: AppColors.textSecondary),
                                          ),
                                        );
                                      }
                                      return Hero(
                                        tag: 'car_image_${widget.car.id}_$index',
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          fadeInDuration: const Duration(milliseconds: 300),
                                          fadeOutDuration: const Duration(milliseconds: 150),
                                          placeholder: (context, url) => Container(
                                            color: AppColors.white,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.primary,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) {
                                            debugPrint('❌ Error loading car image: $url - $error');
                                            return Container(
                                              color: AppColors.background,
                                              child: const Center(
                                                child: Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                              ),
                                            );
                                          },
                                          maxWidthDiskCache: 1200,
                                          maxHeightDiskCache: 900,
                                        ),
                                      );
                                    },
                                  ),
                                  // Indicators للصور المتعددة
                                  if (widget.car.images.length > 1)
                                    Positioned(
                                      bottom: 16,
                                      left: 0,
                                      right: 0,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(
                                          widget.car.images.length,
                                          (index) => AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            margin: const EdgeInsets.symmetric(horizontal: 4),
                                            width: index == _currentImageIndex ? 24 : 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              color: index == _currentImageIndex
                                                  ? AppColors.primary
                                                  : AppColors.white.withValues(alpha: 0.6),
                                              border: Border.all(
                                                color: index == _currentImageIndex
                                                    ? AppColors.primary
                                                    : AppColors.white,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      // معلومات السيارة
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.car.title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  '﷼ ${widget.car.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (widget.car.description.isNotEmpty) ...[
                              Text(
                                widget.car.description,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 20),
                            ],
                            FeatureChips.buildCarFeatures(widget.car),
                            const SizedBox(height: 24),
                            // زر الاتصال
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: () => MapHelpers.launchPhoneCall(widget.car.sellerPhone, context),
                                icon: const Icon(Icons.phone, size: 24),
                                label: const Text(
                                  'اتصال بالمالك',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.white,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // زر عرض التفاصيل الكاملة
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: () {
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
                                icon: const Icon(Icons.open_in_full, size: 24),
                                label: const Text(
                                  'عرض التفاصيل الكاملة',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
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
              ),
            ],
          ),
        );
      },
    );
  }
}
