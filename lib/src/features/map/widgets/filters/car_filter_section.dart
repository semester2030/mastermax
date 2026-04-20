import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import 'filter_state.dart';
import 'filter_common_widgets.dart';
import 'property_filter_section.dart';

/// قوائم البيانات للسيارات
class CarFilterData {
  static const List<String> carMakes = [
    'تويوتا',
    'هونداي',
    'فورد',
    'نيسان',
    'كيا',
    'شفروليه',
    'مرسيدس',
    'بي ام دبليو',
    'لكزس',
    'جي إم سي'
  ];
  static const List<String> carTypes = [
    'سيدان',
    'دفع رباعي',
    'بيك اب',
    'فان',
    'كوبيه',
    'هاتشباك'
  ];
  static const List<String> fuelTypes = ['بنزين', 'ديزل', 'هايبرد', 'كهربائي'];
  static const List<String> transmissionTypes = ['أوتوماتيك', 'يدوي'];
  static const List<String> carFeatures = [
    'نظام ملاحة',
    'كاميرا خلفية',
    'حساسات',
    'فتحة سقف',
    'مثبت سرعة',
    'بلوتوث',
    'شاشة لمس',
    'تحكم بالمقود'
  ];
  static const List<String> carColors = [
    'أبيض',
    'أسود',
    'فضي',
    'أحمر',
    'أزرق',
    'رمادي'
  ];
  static const List<String> carConditions = [
    'جديد',
    'كالجديد',
    'مستعمل - ممتاز',
    'مستعمل - جيد',
    'يحتاج صيانة'
  ];
  static const List<String> bodyStyles = [
    'سيدان',
    'هاتشباك',
    'كوبيه',
    'كروس أوفر',
    'دفع رباعي',
    'بيك أب',
    'فان',
    'واجن'
  ];
  static const List<String> seatsCount = [
    '2 مقاعد',
    '4 مقاعد',
    '5 مقاعد',
    '6 مقاعد',
    '7 مقاعد',
    '8 مقاعد',
    'أكثر من 8'
  ];
  static const List<String> cylinders = [
    '3 سلندر',
    '4 سلندر',
    '6 سلندر',
    '8 سلندر',
    '10 سلندر',
    '12 سلندر'
  ];
  static const List<String> trimLevels = [
    'ستاندرد',
    'فل',
    'نص فل',
    'فل كامل',
    'بريميوم',
    'بلاتينيوم',
    'سبورت'
  ];
}

/// قسم فلاتر السيارات
class CarFilterSection extends StatelessWidget {
  final FilterState state;
  final VoidCallback onUpdate;

  const CarFilterSection({
    super.key,
    required this.state,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // معلومات السيارة
        const FilterSectionTitle(title: 'معلومات السيارة'),
        CarBasicInfo(
          state: state,
          onUpdate: onUpdate,
        ),
        const SizedBox(height: 24),

        // السعر وسنة الصنع
        const FilterSectionTitle(title: 'السعر وسنة الصنع'),
        CarPriceAndYear(
          state: state,
          onUpdate: onUpdate,
        ),
        const SizedBox(height: 24),

        // الموقع
        const FilterSectionTitle(title: 'الموقع'),
        LocationSelection(
          selectedCity: state.selectedCity,
          selectedDistrict: null,
          onCityChanged: (city) {
            state.selectedCity = city;
            onUpdate();
          },
          onDistrictChanged: (_) {},
          cities: PropertyFilterData.cities,
          districts: const [], // السيارات لا تحتاج أحياء
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// قسم فلاتر السيارات المتقدمة
class CarAdvancedFilterSection extends StatelessWidget {
  final FilterState state;
  final VoidCallback onUpdate;

  const CarAdvancedFilterSection({
    super.key,
    required this.state,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // المواصفات الفنية
        const FilterSectionTitle(title: 'المواصفات الفنية'),
        CarTechnicalSpecs(
          state: state,
          onUpdate: onUpdate,
        ),
        const SizedBox(height: 24),

        // حالة السيارة
        const FilterSectionTitle(title: 'حالة السيارة'),
        FilterDropdown(
          value: state.selectedCarCondition,
          items: CarFilterData.carConditions,
          hint: 'اختر حالة السيارة',
          onChanged: (value) {
            state.selectedCarCondition = value;
            onUpdate();
          },
        ),
        const SizedBox(height: 24),

        // المميزات
        const FilterSectionTitle(title: 'المميزات'),
        CarFeaturesGrid(
          selectedFeatures: state.selectedCarFeatures,
          onFeatureToggled: (feature) {
            if (state.selectedCarFeatures.contains(feature)) {
              state.selectedCarFeatures.remove(feature);
            } else {
              state.selectedCarFeatures.add(feature);
            }
            onUpdate();
          },
        ),
        const SizedBox(height: 24),

        // معلومات إضافية
        const FilterSectionTitle(title: 'معلومات إضافية'),
        AdvancedCarFeatures(
          state: state,
          onUpdate: onUpdate,
        ),
      ],
    );
  }
}

/// معلومات السيارة الأساسية
class CarBasicInfo extends StatelessWidget {
  final FilterState state;
  final VoidCallback onUpdate;

  const CarBasicInfo({
    super.key,
    required this.state,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilterDropdown(
          value: state.selectedCarMake,
          items: CarFilterData.carMakes,
          hint: 'اختر الشركة المصنعة',
          onChanged: (value) {
            state.selectedCarMake = value;
            onUpdate();
          },
        ),
        const SizedBox(height: 8),
        FilterDropdown(
          value: state.selectedCarType,
          items: CarFilterData.carTypes,
          hint: 'اختر نوع السيارة',
          onChanged: (value) {
            state.selectedCarType = value;
            onUpdate();
          },
        ),
        const SizedBox(height: 8),
        FilterDropdown(
          value: state.selectedCarColor,
          items: CarFilterData.carColors,
          hint: 'اختر لون السيارة',
          onChanged: (value) {
            state.selectedCarColor = value;
            onUpdate();
          },
        ),
      ],
    );
  }
}

/// السعر وسنة الصنع
class CarPriceAndYear extends StatelessWidget {
  final FilterState state;
  final VoidCallback onUpdate;

  const CarPriceAndYear({
    super.key,
    required this.state,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilterRangeSlider(
          values: state.priceRange,
          min: 0,
          max: 10000000,
          divisions: 100,
          startLabel: '${state.priceRange.start.round()} ريال',
          endLabel: '${state.priceRange.end.round()} ريال',
          minLabel: '0 ريال',
          maxLabel: '10,000,000 ريال',
          onChanged: (values) {
            state.priceRange = values;
            onUpdate();
          },
        ),
        const SizedBox(height: 16),
        FilterRangeSlider(
          values: state.yearRange,
          min: 2000,
          max: 2024,
          divisions: 24,
          startLabel: state.yearRange.start.round().toString(),
          endLabel: state.yearRange.end.round().toString(),
          minLabel: '2000',
          maxLabel: '2024',
          onChanged: (values) {
            state.yearRange = values;
            onUpdate();
          },
        ),
      ],
    );
  }
}

/// المواصفات الفنية
class CarTechnicalSpecs extends StatelessWidget {
  final FilterState state;
  final VoidCallback onUpdate;

  const CarTechnicalSpecs({
    super.key,
    required this.state,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilterDropdown(
          value: state.selectedFuelType,
          items: CarFilterData.fuelTypes,
          hint: 'اختر نوع الوقود',
          onChanged: (value) {
            state.selectedFuelType = value;
            onUpdate();
          },
        ),
        const SizedBox(height: 8),
        FilterDropdown(
          value: state.selectedTransmission,
          items: CarFilterData.transmissionTypes,
          hint: 'اختر نوع ناقل الحركة',
          onChanged: (value) {
            state.selectedTransmission = value;
            onUpdate();
          },
        ),
        const SizedBox(height: 16),
        FilterRangeSlider(
          values: state.kmRange,
          min: 0,
          max: 300000,
          divisions: 60,
          startLabel: '${state.kmRange.start.round()} كم',
          endLabel: '${state.kmRange.end.round()} كم',
          minLabel: '0 كم',
          maxLabel: '300,000 كم',
          onChanged: (values) {
            state.kmRange = values;
            onUpdate();
          },
        ),
      ],
    );
  }
}

/// شبكة مميزات السيارة
class CarFeaturesGrid extends StatelessWidget {
  final List<String> selectedFeatures;
  final ValueChanged<String> onFeatureToggled;

  const CarFeaturesGrid({
    super.key,
    required this.selectedFeatures,
    required this.onFeatureToggled,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: CarFilterData.carFeatures
          .map((feature) => CarFeatureButton(
                feature: feature,
                isSelected: selectedFeatures.contains(feature),
                onTap: () => onFeatureToggled(feature),
              ))
          .toList(),
    );
  }
}

/// زر مميزة السيارة
class CarFeatureButton extends StatelessWidget {
  final String feature;
  final bool isSelected;
  final VoidCallback onTap;

  const CarFeatureButton({
    super.key,
    required this.feature,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? ColorUtils.withOpacity(AppColors.primary, 0.1)
          : AppColors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.primaryLight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getCarFeatureIcon(feature),
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
              const SizedBox(height: 4),
              Text(
                feature,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCarFeatureIcon(String feature) {
    switch (feature) {
      case 'نظام ملاحة':
        return Icons.gps_fixed;
      case 'كاميرا خلفية':
        return Icons.camera_rear;
      case 'حساسات':
        return Icons.sensors;
      case 'فتحة سقف':
        return Icons.wb_sunny;
      case 'مثبت سرعة':
        return Icons.speed;
      case 'بلوتوث':
        return Icons.bluetooth;
      case 'شاشة لمس':
        return Icons.touch_app;
      case 'تحكم بالمقود':
        return Icons.airline_seat_recline_normal;
      default:
        return Icons.check_box;
    }
  }
}

/// المميزات المتقدمة للسيارات
class AdvancedCarFeatures extends StatelessWidget {
  final FilterState state;
  final VoidCallback onUpdate;

  const AdvancedCarFeatures({
    super.key,
    required this.state,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const FilterSectionTitle(title: 'مواصفات السيارة الأساسية'),
        FilterDropdown(
          value: state.selectedBodyStyle,
          items: CarFilterData.bodyStyles,
          hint: 'شكل الهيكل',
          onChanged: (value) {
            state.selectedBodyStyle = value;
            onUpdate();
          },
        ),
        const SizedBox(height: 8),
        FilterDropdown(
          value: state.selectedSeatsCount,
          items: CarFilterData.seatsCount,
          hint: 'عدد المقاعد',
          onChanged: (value) {
            state.selectedSeatsCount = value;
            onUpdate();
          },
        ),
        const SizedBox(height: 8),
        FilterDropdown(
          value: state.selectedCylinders,
          items: CarFilterData.cylinders,
          hint: 'عدد السلندرات',
          onChanged: (value) {
            state.selectedCylinders = value;
            onUpdate();
          },
        ),
        const SizedBox(height: 8),
        FilterDropdown(
          value: state.selectedTrimLevel,
          items: CarFilterData.trimLevels,
          hint: 'مستوى الفئة',
          onChanged: (value) {
            state.selectedTrimLevel = value;
            onUpdate();
          },
        ),

        const SizedBox(height: 16),
        const FilterSectionTitle(title: 'أنظمة السلامة والمساعدة'),
        FilterSwitchTile(
          title: 'كاميرا 360',
          value: state.has360Camera,
          onChanged: (value) {
            state.has360Camera = value;
            onUpdate();
          },
          icon: Icons.camera,
        ),
        FilterSwitchTile(
          title: 'سقف بانورامي',
          value: state.hasPanoramicRoof,
          onChanged: (value) {
            state.hasPanoramicRoof = value;
            onUpdate();
          },
          icon: Icons.wb_sunny,
        ),
        FilterSwitchTile(
          title: 'شاشة عرض أمامية',
          value: state.hasHeadUpDisplay,
          onChanged: (value) {
            state.hasHeadUpDisplay = value;
            onUpdate();
          },
          icon: Icons.display_settings,
        ),

        const SizedBox(height: 16),
        const FilterSectionTitle(title: 'الكماليات والراحة'),
        FilterSwitchTile(
          title: 'شحن لاسلكي',
          value: state.hasWirelessCharging,
          onChanged: (value) {
            state.hasWirelessCharging = value;
            onUpdate();
          },
          icon: Icons.battery_charging_full,
        ),
        FilterSwitchTile(
          title: 'تشغيل عن بعد',
          value: state.hasRemoteStart,
          onChanged: (value) {
            state.hasRemoteStart = value;
            onUpdate();
          },
          icon: Icons.key,
        ),

        const SizedBox(height: 16),
        const FilterSectionTitle(title: 'المقاعد'),
        FilterSwitchTile(
          title: 'مقاعد مهواة',
          value: state.hasVentilatedSeats,
          onChanged: (value) {
            state.hasVentilatedSeats = value;
            onUpdate();
          },
          icon: Icons.airline_seat_recline_extra,
        ),
        FilterSwitchTile(
          title: 'مقاعد بذاكرة',
          value: state.hasMemorySeats,
          onChanged: (value) {
            state.hasMemorySeats = value;
            onUpdate();
          },
          icon: Icons.chair,
        ),
        FilterSwitchTile(
          title: 'مقاعد مساج',
          value: state.hasMassageSeats,
          onChanged: (value) {
            state.hasMassageSeats = value;
            onUpdate();
          },
          icon: Icons.chair_alt,
        ),
        FilterSwitchTile(
          title: 'صف ثالث',
          value: state.hasThirdRow,
          onChanged: (value) {
            state.hasThirdRow = value;
            onUpdate();
          },
          icon: Icons.event_seat,
        ),
      ],
    );
  }
}
