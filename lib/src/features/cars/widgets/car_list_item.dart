import 'package:flutter/material.dart';
import '../models/car_model.dart';
import '../../../core/utils/color_utils.dart';

class CarListItem extends StatelessWidget {
  final CarModel car;
  final VoidCallback? onTap;

  const CarListItem({
    required this.car,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    car.mainImage,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Theme.of(context).colorScheme.surface,
                        child: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onSurface),
                      );
                    },
                  ),
                ),
                if (car.has360View || car.hasInteriorView || car.virtualTourUrl != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        if (car.has360View)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ColorUtils.withOpacity(Theme.of(context).colorScheme.onSurface, 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.view_in_ar,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '360°',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (car.hasInteriorView) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ColorUtils.withOpacity(Theme.of(context).colorScheme.onSurface, 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.airline_seat_recline_normal,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 16,
                            ),
                          ),
                        ],
                        if (car.virtualTourUrl != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ColorUtils.withOpacity(Theme.of(context).colorScheme.onSurface, 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.panorama_horizontal,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '﷼ ${car.price}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          car.address,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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