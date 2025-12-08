import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/car_provider.dart';
import '../models/car_model.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../map/providers/map_state.dart';

class CarListScreen extends StatefulWidget {
  const CarListScreen({super.key});

  @override
  State<CarListScreen> createState() => _CarListScreenState();
}

class _CarListScreenState extends State<CarListScreen> {
  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  Future<void> _loadCars() async {
    await context.read<CarProvider>().loadCars();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Consumer2<CarProvider, MapState>(
      builder: (context, carProvider, mapState, child) {
        final cars = mapState.visibleCars;
        
        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'السيارات (${cars.length})',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.map_outlined, color: colorScheme.primary),
                onPressed: () {
                  Navigator.pushNamed(context, '/map');
                },
              ),
              IconButton(
                icon: Icon(Icons.filter_list, color: colorScheme.primary),
                onPressed: () {
                  // TODO: تنفيذ الفلترة
                },
              ),
            ],
          ),
          body: _buildBody(cars, carProvider.isLoading, colorScheme, textTheme),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, '/cars/add');
            },
            backgroundColor: colorScheme.primary,
            child: Icon(Icons.add, color: colorScheme.onPrimary),
          ),
        );
      },
    );
  }

  Widget _buildBody(List<CarModel> cars, bool isLoading, ColorScheme colorScheme, TextTheme textTheme) {
    if (isLoading && cars.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      );
    }

    if (cars.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد سيارات متاحة',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCars,
      color: colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cars.length,
        itemBuilder: (context, index) {
          final car = cars[index];
          return _buildCarCard(car, colorScheme, textTheme);
        },
      ),
    );
  }

  Widget _buildCarCard(CarModel car, ColorScheme colorScheme, TextTheme textTheme) {
    return custom_animations.AnimatedScale(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/car-details',
              arguments: car.id,
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: car.images.isNotEmpty
                        ? Image.network(
                            car.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: colorScheme.surface,
                                child: Icon(
                                  Icons.directions_car_outlined,
                                  color: colorScheme.primary,
                                  size: 48,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: colorScheme.surface,
                            child: Icon(
                              Icons.directions_car_outlined,
                              color: colorScheme.primary,
                              size: 48,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              car.address,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildFeature(Icons.calendar_today, '${car.year}', colorScheme, textTheme),
                          _buildFeature(Icons.speed, '${car.kilometers} كم', colorScheme, textTheme),
                          _buildFeature(Icons.local_gas_station, car.fuelType, colorScheme, textTheme),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${car.price} ريال',
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text, ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          text,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
} 