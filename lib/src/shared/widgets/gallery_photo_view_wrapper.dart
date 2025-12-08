import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../core/theme/app_colors.dart';

class GalleryPhotoViewWrapper extends StatefulWidget {
  final List<String> galleryItems;
  final int initialIndex;
  final PageController pageController;
  final Axis scrollDirection;
  final bool isNetworkImage;

  const GalleryPhotoViewWrapper({
    super.key,
    required this.galleryItems,
    this.initialIndex = 0,
    required this.pageController,
    this.scrollDirection = Axis.horizontal,
    this.isNetworkImage = true,
  });

  @override
  State<GalleryPhotoViewWrapper> createState() => _GalleryPhotoViewWrapperState();
}

class _GalleryPhotoViewWrapperState extends State<GalleryPhotoViewWrapper> {
  late int currentIndex = widget.initialIndex;

  void onPageChanged(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: widget.isNetworkImage
                    ? NetworkImage(widget.galleryItems[index])
                    : AssetImage(widget.galleryItems[index]) as ImageProvider,
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            itemCount: widget.galleryItems.length,
            loadingBuilder: (context, event) => Center(
              child: SizedBox(
                width: 40.0,
                height: 40.0,
                child: CircularProgressIndicator(
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
            ),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: widget.pageController,
            onPageChanged: onPageChanged,
            scrollDirection: widget.scrollDirection,
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  "${currentIndex + 1}/${widget.galleryItems.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
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