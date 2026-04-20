import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/directions_service.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';

/// Widget لعرض الاتجاهات خطوة بخطوة
class TextDirectionsWidget extends StatefulWidget {
  final LatLng origin;
  final LatLng destination;
  final TravelMode travelMode;
  final bool showSteps;

  const TextDirectionsWidget({
    super.key,
    required this.origin,
    required this.destination,
    this.travelMode = TravelMode.driving,
    this.showSteps = true,
  });

  @override
  State<TextDirectionsWidget> createState() => _TextDirectionsWidgetState();
}

class _TextDirectionsWidgetState extends State<TextDirectionsWidget> {
  final DirectionsService _directionsService = DirectionsService();
  Map<String, dynamic>? _routeInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDirections();
  }

  Future<void> _loadDirections() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final routeInfo = await _directionsService.getRouteInfo(
        origin: widget.origin,
        destination: widget.destination,
        mode: widget.travelMode,
      );

      setState(() {
        _routeInfo = routeInfo;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading directions: $e');
      setState(() {
        _routeInfo = null;
        _isLoading = false;
      });
    }
  }

  String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'الاتجاهات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_routeInfo == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'لا يمكن الحصول على الاتجاهات',
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
            )
          else ...[
            // ملخص المسار
            _buildRouteSummary(_routeInfo!),
            const SizedBox(height: 16),
            if (widget.showSteps) ...[
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'خطوات المسار',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildStepsList(_routeInfo!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRouteSummary(Map<String, dynamic> routeInfo) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            icon: Icons.straighten,
            label: 'المسافة',
            value: routeInfo['distance_text'] ?? '',
          ),
          _buildSummaryItem(
            icon: Icons.access_time,
            label: 'الوقت',
            value: routeInfo['duration_text'] ?? '',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepsList(Map<String, dynamic> routeInfo) {
    final steps = routeInfo['steps'] as List<dynamic>? ?? [];

    if (steps.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'لا توجد خطوات متاحة',
            style: TextStyle(color: AppColors.textLight),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index] as Map<String, dynamic>;
        return _buildStepItem(step, index + 1);
      },
    );
  }

  Widget _buildStepItem(Map<String, dynamic> step, int stepNumber) {
    final instruction = _stripHtmlTags(step['instruction'] ?? '');
    final distance = step['distance'] ?? '';
    final duration = step['duration'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$stepNumber',
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.straighten,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      distance,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: instruction));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم نسخ التعليمات'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


