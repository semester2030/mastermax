import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/map_state.dart';
import '../widgets/map_view.dart';
import '../../../core/theme/app_colors.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mapState = context.watch<MapState>();

    return Scaffold(
      body: Stack(
        children: [
          Consumer<MapState>(
            builder: (context, state, child) {
              return state.mapController == null
                  ? const Center(child: CircularProgressIndicator())
                  : const SizedBox.expand();
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Column(
              children: [
                _MapButton(
                  icon: Icons.layers,
                  onPressed: () => mapState.toggleMapStyle(),
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.add,
                  onPressed: () => mapState.zoomIn(),
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.remove,
                  onPressed: () => mapState.zoomOut(),
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.my_location,
                  onPressed: () => mapState.centerToCurrentLocation(),
                ),
              ],
            ),
          ),
          const MapView(),
          _buildCitySelector(context),
        ],
      ),
    );
  }

  Widget _buildCitySelector(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      child: Card(
        elevation: 4,
        color: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCityButton(
                context,
                'الرياض',
                () => context.read<MapState>().mapController?.setCamera(MapState.riyadh),
              ),
              const SizedBox(height: 8),
              _buildCityButton(
                context,
                'جدة',
                () => context.read<MapState>().mapController?.setCamera(MapState.jeddah),
              ),
              const SizedBox(height: 8),
              _buildCityButton(
                context,
                'مكة',
                () => context.read<MapState>().mapController?.setCamera(MapState.makkah),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCityButton(BuildContext context, String title, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: true,
      onPressed: onPressed,
      backgroundColor: AppColors.surface,
      child: Icon(icon, color: AppColors.primary),
    );
  }
} 