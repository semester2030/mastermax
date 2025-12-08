import 'package:flutter/material.dart';
import '../models/car_model.dart';
import '../../../shared/utils/formatters.dart';

class CarSpecsSection extends StatelessWidget {
  final CarModel vehicle;

  const CarSpecsSection({
    required this.vehicle, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مواصفات السيارة',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildSpecRow(
            'الماركة',
            vehicle.brand,
            'الموديل',
            vehicle.model,
          ),
          const Divider(height: 24),
          _buildSpecRow(
            'سنة الصنع',
            vehicle.year.toString(),
            'عدد الكيلومترات',
            '${formatNumber(vehicle.kilometers)} كم',
          ),
          const Divider(height: 24),
          _buildSpecRow(
            'الحالة',
            _getConditionText(vehicle.condition),
            'ناقل الحركة',
            _getTransmissionText(vehicle.transmission),
          ),
          const Divider(height: 24),
          _buildSpecRow(
            'نوع الوقود',
            _getFuelTypeText(vehicle.fuelType),
            '',
            '',
            showSecond: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(
    String label1,
    String value1,
    String label2,
    String value2, {
    bool showSecond = true,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label1,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value1,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (showSecond) ...[
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label2,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value2,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getConditionText(String condition) {
    switch (condition.toLowerCase()) {
      case 'new':
        return 'جديد';
      case 'used':
        return 'مستعمل';
      default:
        return condition;
    }
  }

  String _getTransmissionText(String transmission) {
    switch (transmission.toLowerCase()) {
      case 'automatic':
        return 'أوتوماتيك';
      case 'manual':
        return 'يدوي';
      default:
        return transmission;
    }
  }

  String _getFuelTypeText(String fuelType) {
    switch (fuelType.toLowerCase()) {
      case 'petrol':
        return 'بنزين';
      case 'diesel':
        return 'ديزل';
      case 'hybrid':
        return 'هجين';
      case 'electric':
        return 'كهربائي';
      default:
        return fuelType;
    }
  }
} 