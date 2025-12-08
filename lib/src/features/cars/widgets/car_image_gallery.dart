import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/color_utils.dart';

class CarImageGallery extends StatefulWidget {
  final List<String> images;
  final double height;
  final bool showIndicator;

  const CarImageGallery({
    required this.images, super.key,
    this.height = 200,
    this.showIndicator = true,
  });

  @override
  State<CarImageGallery> createState() => _CarImageGalleryState();
}

class _CarImageGalleryState extends State<CarImageGallery> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('لا توجد صور متاحة'),
        ),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              if (mounted) {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: widget.images[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary),
                  ),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              );
            },
          ),
        ),
        if (widget.showIndicator && widget.images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.images.asMap().entries.map((entry) {
                return GestureDetector(
                  onTap: () => _pageController.animateToPage(
                    entry.key,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColorUtils.withOpacity(Theme.of(context).colorScheme.onPrimary, _currentIndex == entry.key ? 0.9 : 0.4),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
} 