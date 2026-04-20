import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../models/video_model.dart';

/// خريطة بسيطة لموقع إعلان السبوتلايت (عقار/سيارة) — بدون شريط بحث أو قوائم الخريطة الرئيسية.
class SpotlightLocationMapScreen extends StatefulWidget {
  const SpotlightLocationMapScreen({super.key, required this.video});

  final VideoModel video;

  @override
  State<SpotlightLocationMapScreen> createState() =>
      _SpotlightLocationMapScreenState();
}

class _SpotlightLocationMapScreenState extends State<SpotlightLocationMapScreen> {
  late final LatLng _target;
  late final Set<Marker> _markers;

  static bool _hasValidLocation(VideoModel v) {
    final p = v.location;
    const eps = 1e-5;
    if (p.latitude.abs() < eps && p.longitude.abs() < eps) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.video.location;
    _target = LatLng(p.latitude, p.longitude);
    final title = widget.video.title.trim().isNotEmpty
        ? widget.video.title.trim()
        : 'موقع الإعلان';
    final snippet = widget.video.address.trim().isNotEmpty
        ? widget.video.address.trim()
        : null;
    _markers = {
      Marker(
        markerId: const MarkerId('spotlight_listing'),
        position: _target,
        infoWindow: InfoWindow(
          title: title,
          snippet: snippet,
        ),
      ),
    };
  }

  Future<void> _openGoogleMapsDirections() async {
    final lat = _target.latitude;
    final lng = _target.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    final fallback = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر فتح خرائط Google')),
        );
      }
    } catch (e) {
      debugPrint('openGoogleMapsDirections: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر فتح الرابط')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidLocation(widget.video)) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          title: const Text('الموقع'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'لم يُحدد موقع جغرافي لهذا المقطع على الخريطة.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'العودة للفيديو',
        ),
        title: const Text('موقع الإعلان'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _target,
              zoom: 18,
              tilt: 0,
              bearing: 0,
            ),
            markers: _markers,
            mapType: MapType.hybrid,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _openGoogleMapsDirections,
                  icon: const Icon(Icons.directions),
                  label: const Text('التوجيه في Google Maps'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
