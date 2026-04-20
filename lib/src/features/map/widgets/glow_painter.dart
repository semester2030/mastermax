import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Custom Painter للتوهج الاحترافي حول الموقع على الخريطة
/// 
/// يستخدم هذا الـ Painter لرسم توهج متعدد الطبقات حول موقع العقار أو السيارة
/// على الخريطة لإبرازه بشكل احترافي
class GlowPainter extends CustomPainter {
  final Offset center;
  final Color color;
  
  const GlowPainter({
    required this.center,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // ✅ رسم دوائر متعددة للتوهج الاحترافي (من الخارج للداخل)
    final radii = [60.0, 45.0, 30.0, 15.0];
    final opacities = [0.15, 0.25, 0.35, 0.5];
    
    for (int i = 0; i < radii.length; i++) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: opacities[i])
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      
      canvas.drawCircle(center, radii[i], glowPaint);
    }
    
    // ✅ حلقة خارجية للتوهج
    final outerRingPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 25, outerRingPaint);
    
    // ✅ نقطة مركزية قوية
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10, centerPaint);
    
    // ✅ حلقة داخلية
    final innerRingPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 12, innerRingPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
