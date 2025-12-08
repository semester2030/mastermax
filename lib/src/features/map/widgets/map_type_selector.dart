import 'package:flutter/material.dart';
import '../providers/map_state.dart';
import '../../../core/utils/color_utils.dart';

class MapTypeSelector extends StatelessWidget {
  final MapFilterType selectedType;
  final Function(MapFilterType) onTypeChanged;

  const MapTypeSelector({
    required this.selectedType, required this.onTypeChanged, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _TypeButton(
            isSelected: selectedType == MapFilterType.realEstate,
            onTap: () => onTypeChanged(MapFilterType.realEstate),
            icon: Icons.home,
            label: 'عقارات',
            startColor: const Color(0xFF1976D2),
            endColor: const Color(0xFF64B5F6),
          ),
          const SizedBox(width: 12),
          _TypeButton(
            isSelected: selectedType == MapFilterType.cars,
            onTap: () => onTypeChanged(MapFilterType.cars),
            icon: Icons.directions_car,
            label: 'سيارات',
            startColor: const Color(0xFF7B1FA2),
            endColor: const Color(0xFFBA68C8),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color startColor;
  final Color endColor;

  const _TypeButton({
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.label,
    required this.startColor,
    required this.endColor,
  });

  @override
  State<_TypeButton> createState() => _TypeButtonState();
}

class _TypeButtonState extends State<_TypeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isSelected ? [
              widget.startColor,
              widget.endColor,
            ] : [
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: widget.isSelected 
                ? ColorUtils.withOpacity(widget.startColor, 0.5)
                : ColorUtils.withOpacity(Theme.of(context).shadowColor, 0.1),
              offset: _isPressed ? const Offset(2, 2) : const Offset(5, 5),
              blurRadius: _isPressed ? 5 : 10,
              spreadRadius: _isPressed ? 1 : 2,
            ),
            BoxShadow(
              color: ColorUtils.withOpacity(Theme.of(context).colorScheme.onPrimary, 0.5),
              offset: _isPressed ? const Offset(-1, -1) : const Offset(-2, -2),
              blurRadius: _isPressed ? 5 : 10,
              spreadRadius: _isPressed ? 1 : 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              size: 24,
              color: Theme.of(context).colorScheme.onPrimary,
              shadows: [
                Shadow(
                  color: ColorUtils.withOpacity(Theme.of(context).shadowColor, 0.3),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                shadows: [
                  Shadow(
                    color: ColorUtils.withOpacity(Theme.of(context).shadowColor, 0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 