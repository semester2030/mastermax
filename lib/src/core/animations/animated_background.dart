import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/utils/color_utils.dart';

class AnimatedGradientBackground extends StatefulWidget {
  final List<Color> colors;
  final Duration duration;
  final Widget child;

  const AnimatedGradientBackground({
    required this.colors, required this.child, super.key,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Color> _colors;
  late List<Color> _nextColors;

  @override
  void initState() {
    super.initState();
    _colors = List.from(widget.colors);
    _nextColors = List.from(widget.colors);
    _nextColors.add(_nextColors.removeAt(0));

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: List.generate(
                _colors.length,
                (index) => Color.lerp(
                  _colors[index],
                  _nextColors[index],
                  _controller.value,
                )!,
              ),
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class AnimatedShapesBackground extends StatefulWidget {
  final Color color;
  final int numberOfShapes;
  final Widget child;

  const AnimatedShapesBackground({
    required this.color, required this.child, super.key,
    this.numberOfShapes = 20,
  });

  @override
  State<AnimatedShapesBackground> createState() => _AnimatedShapesBackgroundState();
}

class _AnimatedShapesBackgroundState extends State<AnimatedShapesBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Shape> shapes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    shapes = List.generate(
      widget.numberOfShapes,
      (index) => Shape(
        color: ColorUtils.withOpacity(widget.color, 0.1),
        size: math.Random().nextDouble() * 50 + 20,
        position: Offset(
          math.Random().nextDouble() * 400,
          math.Random().nextDouble() * 800,
        ),
        angle: math.Random().nextDouble() * 2 * math.pi,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          painter: ShapesPainter(shapes, _controller),
          size: Size.infinite,
        ),
        widget.child,
      ],
    );
  }
}

class Shape {
  final Color color;
  final double size;
  final Offset position;
  final double angle;

  Shape({
    required this.color,
    required this.size,
    required this.position,
    required this.angle,
  });
}

class ShapesPainter extends CustomPainter {
  final List<Shape> shapes;
  final Animation<double> animation;

  ShapesPainter(this.shapes, this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (var shape in shapes) {
      final paint = Paint()
        ..color = shape.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(
        shape.position.dx + math.sin(animation.value * 2 * math.pi + shape.angle) * 20,
        shape.position.dy + math.cos(animation.value * 2 * math.pi + shape.angle) * 20,
      );
      canvas.rotate(animation.value * 2 * math.pi * (shape.angle / math.pi));

      if (shape.angle < math.pi / 2) {
        // رسم دائرة
        canvas.drawCircle(Offset.zero, shape.size / 2, paint);
      } else if (shape.angle < math.pi) {
        // رسم مربع
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: shape.size,
            height: shape.size,
          ),
          paint,
        );
      } else {
        // رسم مثلث
        final path = Path();
        path.moveTo(0, -shape.size / 2);
        path.lineTo(shape.size / 2, shape.size / 2);
        path.lineTo(-shape.size / 2, shape.size / 2);
        path.close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 