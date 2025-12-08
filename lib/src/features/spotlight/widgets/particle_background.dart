import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:mastermax_2030/src/core/theme/app_colors.dart';
import 'package:mastermax_2030/src/core/utils/color_utils.dart';

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> with TickerProviderStateMixin {
  late List<ParticleModel> particles;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    particles = List.generate(50, (index) => ParticleModel());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: ParticlePainter(particles, _controller.value),
        );
      },
    );
  }
}

class ParticleModel {
  double x = math.Random().nextDouble();
  double y = math.Random().nextDouble();
  double size = math.Random().nextDouble() * 2 + 1;
  double speed = math.Random().nextDouble() * 0.2 + 0.1;
}

class ParticlePainter extends CustomPainter {
  final List<ParticleModel> particles;
  final double animation;

  ParticlePainter(this.particles, this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ColorUtils.withOpacity(AppColors.surface, 0.1);

    for (var particle in particles) {
      final position = Offset(
        particle.x * size.width,
        (particle.y + animation * particle.speed) % 1.0 * size.height,
      );
      canvas.drawCircle(position, particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
} 