import 'package:flutter/material.dart';
import '../models/property_models.dart';
import '../../../../../core/theme/app_colors.dart';

class InventoryTabWidget extends StatelessWidget {
  final List<PropertyDetails> inventory;

  const InventoryTabWidget({
    required this.inventory, super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (inventory.isEmpty) {
      return const Center(
        child: Text('لا يوجد عقارات في المخزون'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'المخزون',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'إجمالي العقارات: ${inventory.length}',
                style: const TextStyle(
                  color: AppColors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: inventory.length,
            itemBuilder: (context, index) {
              final property = inventory[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: AppColors.secondary,
                child: ExpansionTile(
                  title: Text(
                    property.title,
                    style: const TextStyle(color: AppColors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(property.location),
                      Text('${property.area} متر مربع'),
                      if (property.type != PropertyType.land) ...[
                        Text('${property.rooms} غرف'),
                        Text('${property.bathrooms} حمامات'),
                      ],
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${property.targetPrice} ر.س',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.chartGreen,
                        ),
                      ),
                      Text(
                        '${property.daysInMarket} يوم',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('المساحة', '${property.area} متر مربع'),
                          _buildDetailRow('عدد الغرف', '${property.rooms}'),
                          _buildDetailRow('عدد الحمامات', '${property.bathrooms}'),
                          _buildDetailRow('مفروش', property.isFurnished ? 'نعم' : 'لا'),
                          _buildDetailRow('مدة العرض', '${property.daysInMarket} يوم'),
                          _buildDetailRow('سعر الشراء', '${property.purchasePrice} ر.س'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 