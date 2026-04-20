import 'package:flutter/material.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/theme/app_colors.dart';

class SpotlightMapMarker extends StatefulWidget {
  final String type;
  final bool isSelected;
  final VoidCallback onDoubleTap;
  final String label;

  const SpotlightMapMarker({
    required this.type, required this.isSelected, required this.onDoubleTap, required this.label, super.key,
  });

  @override
  State<SpotlightMapMarker> createState() => _SpotlightMapMarkerState();
}

class _SpotlightMapMarkerState extends State<SpotlightMapMarker> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutBack,
    ));

    _rotateAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutSine,
    ));

    _bounceAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutQuad,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  LinearGradient _getGradient(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LinearGradient(
      colors: [
        widget.type.contains('عقار') ? colorScheme.primary : colorScheme.secondary,
        ColorUtils.withOpacity(AppColors.white, 0.3),
        widget.type.contains('عقار') ? colorScheme.primary : colorScheme.secondary,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, widget.isSelected ? -_bounceAnimation.value : 0),
          child: GestureDetector(
            onDoubleTap: () {
              widget.onDoubleTap();
              _animationController
                ..reset()
                ..forward();
            },
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(_rotateAnimation.value)
                ..rotateY(_rotateAnimation.value),
              alignment: Alignment.center,
              child: Container(
                decoration: BoxDecoration(
                  gradient: _getGradient(context),
                  borderRadius: BorderRadius.circular(widget.isSelected ? 30 : 20),
                  border: Border.all(
                    color: ColorUtils.withOpacity(colorScheme.tertiary, widget.isSelected ? 1 : 0.5),
                    width: widget.isSelected ? 3 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.withOpacity(colorScheme.tertiary, 0.3),
                      blurRadius: widget.isSelected ? 20 : 10,
                      spreadRadius: widget.isSelected ? 5 : 2,
                    ),
                    BoxShadow(
                      color: ColorUtils.withOpacity(AppColors.white, 0.5),
                      blurRadius: 15,
                      spreadRadius: -2,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Container(
                  padding: EdgeInsets.all(widget.isSelected ? 16 : 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.isSelected ? 30 : 20),
                    gradient: LinearGradient(
                      colors: [
                        ColorUtils.withOpacity(AppColors.white, 0.4),
                        ColorUtils.withOpacity(AppColors.white, 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildIcon(context),
                      ),
                      if (widget.isSelected) ...[
                        const SizedBox(width: 8),
                        _buildLabel(context),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // ظل الأيقونة
        Icon(
          widget.type.contains('عقار') ? Icons.home : Icons.directions_car,
          size: widget.isSelected ? 35 : 30,
          color: AppColors.textPrimary.withOpacity(0.26),
        ),
        // الأيقونة الرئيسية
        Icon(
          widget.type.contains('عقار') ? Icons.home : Icons.directions_car,
          size: widget.isSelected ? 35 : 30,
          color: colorScheme.tertiary,
        ),
        // توهج الأيقونة
        Icon(
          widget.type.contains('عقار') ? Icons.home : Icons.directions_car,
          size: widget.isSelected ? 35 : 30,
          color: ColorUtils.withOpacity(AppColors.white, 0.5),
        ),
      ],
    );
  }

  Widget _buildLabel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Text(
            widget.label,
            style: textTheme.titleMedium?.copyWith(
              color: ColorUtils.withOpacity(colorScheme.tertiary, 0.7),
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: ColorUtils.withOpacity(AppColors.textPrimary, 0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
                Shadow(
                  color: ColorUtils.withOpacity(colorScheme.tertiary, 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 