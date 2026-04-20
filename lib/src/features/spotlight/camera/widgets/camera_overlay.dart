import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../screens/camera_screen.dart';
import '../../../../core/theme/app_colors.dart';

class CameraOverlay extends StatelessWidget {
  final CameraMode mode;
  final double panoramaProgress;
  final double threeDProgress;
  final double threeDAngle;

  const CameraOverlay({
    required this.mode, required this.panoramaProgress, required this.threeDProgress, required this.threeDAngle, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // شبكة التوجيه
        _buildGrid(),

        // مؤشر التقدم والتوجيه
        if (mode != CameraMode.normal)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 0,
            right: 0,
            child: _buildProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildGrid() {
    return CustomPaint(
      painter: GridPainter(
        mode: mode,
        angle: threeDAngle,
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // نص التوجيه
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withOpacity(0.54),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getGuidanceText(),
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 8),

          // شريط التقدم
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: mode == CameraMode.panorama
                  ? panoramaProgress
                  : threeDProgress,
              backgroundColor: AppColors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  String _getGuidanceText() {
    switch (mode) {
      case CameraMode.panorama:
        final remaining = (8 - (panoramaProgress * 8)).round();
        return 'التقط $remaining صور أخرى لإكمال البانوراما';
      case CameraMode.threeD:
        final angle = threeDAngle.round();
        return 'قم بتدوير العنصر إلى $angle درجة';
      default:
        return '';
    }
  }
}

class GridPainter extends CustomPainter {
  final CameraMode mode;
  final double angle;

  GridPainter({
    required this.mode,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withOpacity(0.54)
      ..strokeWidth = 1;

    switch (mode) {
      case CameraMode.normal:
        _drawRuleOfThirds(canvas, size, paint);
        break;
      case CameraMode.panorama:
        _drawPanoramaGuide(canvas, size, paint);
        break;
      case CameraMode.threeD:
        _draw3DGuide(canvas, size, paint, angle);
        break;
    }
  }

  void _drawRuleOfThirds(Canvas canvas, Size size, Paint paint) {
    // خطوط أفقية
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );

    // خطوط عمودية
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
  }

  void _drawPanoramaGuide(Canvas canvas, Size size, Paint paint) {
    // إطار للتوجيه
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.1,
        size.height * 0.2,
        size.width * 0.8,
        size.height * 0.6,
      ),
      paint,
    );

    // خطوط التوجيه العمودية
    for (int i = 1; i < 8; i++) {
      final x = size.width * (0.1 + (i * 0.1));
      canvas.drawLine(
        Offset(x, size.height * 0.2),
        Offset(x, size.height * 0.8),
        paint,
      );
    }
  }

  void _draw3DGuide(Canvas canvas, Size size, Paint paint, double angle) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // دائرة التوجيه
    canvas.drawCircle(center, radius, paint);

    // خط الزاوية
    final angleRad = angle * math.pi / 180;
    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * math.cos(angleRad),
        center.dy + radius * math.sin(angleRad),
      ),
      paint..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return mode != oldDelegate.mode || angle != oldDelegate.angle;
  }
} 