import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class LocationFilterContent extends StatefulWidget {
  const LocationFilterContent({super.key});

  @override
  State<LocationFilterContent> createState() => _LocationFilterContentState();
}

class _LocationFilterContentState extends State<LocationFilterContent> {
  String _selectedCity = 'الرياض';
  String _selectedDistrict = 'الملقا';
  double _radius = 5.0;

  final List<String> _cities = [
    'الرياض',
    'جدة',
    'الدمام',
    'مكة المكرمة',
    'المدينة المنورة',
    'الخبر',
    'الظهران',
    'تبوك',
    'أبها',
  ];

  final List<String> _districts = [
    'الملقا',
    'النخيل',
    'الياسمين',
    'الورود',
    'النرجس',
    'العارض',
    'القيروان',
    'حطين',
    'الربيع',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // المدينة
        Text(
          'المدينة',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _cities.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildCityChip(_cities[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // الحي
        Text(
          'الحي',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _districts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildDistrictChip(_districts[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // نطاق البحث
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'نطاق البحث',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_radius.round()} كم',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _radius,
          min: 1,
          max: 20,
          divisions: 19,
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          label: '${_radius.round()} كم',
          onChanged: (value) {
            setState(() {
              _radius = value;
            });
          },
        ),

        // خيارات إضافية
        const SizedBox(height: 24),
        Text(
          'خيارات إضافية',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('قريب من المدارس', true),
        _buildInfoRow('قريب من المساجد', true),
        _buildInfoRow('قريب من الخدمات', true),
        _buildInfoRow('قريب من المواصلات', false),

        // أزرار التحكم
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'إلغاء',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // تطبيق الفلتر
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'تطبيق',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCityChip(String city) {
    final isSelected = _selectedCity == city;
    return InkWell(
      onTap: () => setState(() => _selectedCity = city),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onPrimary.withOpacity(0.24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          city,
          style: TextStyle(
            color: isSelected ? AppColors.textPrimary : AppColors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDistrictChip(String district) {
    final isSelected = _selectedDistrict == district;
    return InkWell(
      onTap: () => setState(() => _selectedDistrict = district),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onPrimary.withOpacity(0.24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          district,
          style: TextStyle(
            color: isSelected ? AppColors.textPrimary : AppColors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, bool isAvailable) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          Icon(
            isAvailable ? Icons.check_circle : Icons.remove_circle,
            color: isAvailable ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onPrimary.withOpacity(0.24),
            size: 20,
          ),
        ],
      ),
    );
  }
} 