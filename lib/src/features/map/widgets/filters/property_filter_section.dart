import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../properties/models/property_model.dart';
import 'filter_state.dart';
import 'filter_common_widgets.dart';

/// قوائم البيانات للعقارات
class PropertyFilterData {
  static const List<String> propertyTypes = ['شقة', 'فيلا', 'عمارة', 'أرض', 'محل تجاري'];
  static const List<String> cities = ['الرياض', 'جدة', 'الدمام', 'مكة', 'المدينة'];
  static const List<String> amenities = ['مكيف', 'مفروش', 'مطبخ', 'مصعد', 'حديقة'];
  static const List<String> districts = ['شمال', 'جنوب', 'شرق', 'غرب', 'وسط المدينة'];
  static const List<String> propertyAges = [
    'جديد',
    'أقل من سنة',
    '1-3 سنوات',
    '3-5 سنوات',
    '5-10 سنوات',
    '10-15 سنة',
    'أكثر من 15 سنة'
  ];
  static const List<String> propertyDirections = [
    'شمالي',
    'جنوبي',
    'شرقي',
    'غربي',
    'شمالي شرقي',
    'شمالي غربي',
    'جنوبي شرقي',
    'جنوبي غربي'
  ];
  static const List<String> streetWidths = [
    'أقل من 10 متر',
    '10-15 متر',
    '15-20 متر',
    '20-30 متر',
    'أكثر من 30 متر'
  ];
}

/// قسم فلاتر العقارات
class PropertyFilterSection extends StatelessWidget {
  final FilterState state;
  final VoidCallback onUpdate;

  const PropertyFilterSection({
    super.key,
    required this.state,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // نوع العقار
        const FilterSectionTitle(title: 'نوع العقار'),
        PropertyTypesGrid(
          selectedType: state.selectedPropertyType,
          onTypeSelected: (type) {
            state.selectedPropertyType = type;
            onUpdate();
          },
        ),
        const SizedBox(height: 24),

        // نوع العرض
        const FilterSectionTitle(title: 'نوع العرض'),
        OfferTypeSelector(
          selectedOfferType: state.selectedOfferType,
          onOfferTypeSelected: (offerType) {
            state.selectedOfferType = offerType;
            onUpdate();
          },
        ),
        const SizedBox(height: 24),

        // نطاق السعر
        const FilterSectionTitle(title: 'نطاق السعر'),
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
        const SizedBox(height: 24),

        // المدينة والحي
        const FilterSectionTitle(title: 'المدينة والحي'),
        LocationSelection(
          selectedCity: state.selectedCity,
          selectedDistrict: state.selectedDistrict,
          onCityChanged: (city) {
            state.selectedCity = city;
            state.selectedDistrict = null;
            onUpdate();
          },
          onDistrictChanged: (district) {
            state.selectedDistrict = district;
            onUpdate();
          },
          cities: PropertyFilterData.cities,
          districts: PropertyFilterData.districts,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// قسم فلاتر العقارات المتقدمة
class PropertyAdvancedFilterSection extends StatelessWidget {
  final FilterState state;
  final VoidCallback onUpdate;

  const PropertyAdvancedFilterSection({
    super.key,
    required this.state,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // المساحة
        const FilterSectionTitle(title: 'المساحة'),
        FilterRangeSlider(
          values: state.areaRange,
          min: 0,
          max: 1000,
          divisions: 50,
          startLabel: '${state.areaRange.start.round()} م²',
          endLabel: '${state.areaRange.end.round()} م²',
          minLabel: '0 م²',
          maxLabel: '1000 م²',
          onChanged: (values) {
            state.areaRange = values;
            onUpdate();
          },
        ),
        const SizedBox(height: 24),

        // عدد الغرف
        const FilterSectionTitle(title: 'عدد الغرف'),
        FilterRangeSlider(
          values: state.roomsRange,
          min: 1,
          max: 10,
          divisions: 9,
          startLabel: '${state.roomsRange.start.round()} غرفة',
          endLabel: '${state.roomsRange.end.round()} غرف',
          minLabel: 'غرفة واحدة',
          maxLabel: '10 غرف',
          onChanged: (values) {
            state.roomsRange = values;
            onUpdate();
          },
        ),
        const SizedBox(height: 24),

        // دورات المياه
        const FilterSectionTitle(title: 'دورات المياه'),
        FilterRangeSlider(
          values: state.bathroomsRange,
          min: 1,
          max: 5,
          divisions: 4,
          startLabel: '${state.bathroomsRange.start.round()} حمام',
          endLabel: '${state.bathroomsRange.end.round()} حمامات',
          minLabel: 'حمام واحد',
          maxLabel: '5 حمامات',
          onChanged: (values) {
            state.bathroomsRange = values;
            onUpdate();
          },
        ),
        const SizedBox(height: 24),

        // المميزات
        const FilterSectionTitle(title: 'المميزات'),
        AmenitiesGrid(
          selectedAmenities: state.selectedAmenities,
          onAmenityToggled: (amenity) {
            if (state.selectedAmenities.contains(amenity)) {
              state.selectedAmenities.remove(amenity);
            } else {
              state.selectedAmenities.add(amenity);
            }
            onUpdate();
          },
        ),
        const SizedBox(height: 24),

        // مميزات إضافية
        const FilterSectionTitle(title: 'مميزات إضافية'),
        AdvancedPropertyFeatures(
          state: state,
          onUpdate: onUpdate,
        ),
      ],
    );
  }
}

/// شبكة أنواع العقارات
class PropertyTypesGrid extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeSelected;

  const PropertyTypesGrid({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
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
      children: PropertyFilterData.propertyTypes
          .map((type) => PropertyTypeButton(
                type: type,
                isSelected: selectedType == type,
                onTap: () => onTypeSelected(type),
              ))
          .toList(),
    );
  }
}

/// زر نوع العقار
class PropertyTypeButton extends StatelessWidget {
  final String type;
  final bool isSelected;
  final VoidCallback onTap;

  const PropertyTypeButton({
    super.key,
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? AppColors.transparent
                  : ColorUtils.withOpacity(AppColors.primary, 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getPropertyTypeIcon(type),
                color: isSelected ? AppColors.white : AppColors.primary,
              ),
              const SizedBox(height: 4),
              Text(
                type,
                style: TextStyle(
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPropertyTypeIcon(String type) {
    switch (type) {
      case 'شقة':
        return Icons.apartment;
      case 'فيلا':
        return Icons.house;
      case 'عمارة':
        return Icons.business;
      case 'أرض':
        return Icons.landscape;
      case 'محل تجاري':
        return Icons.storefront;
      default:
        return Icons.home;
    }
  }
}

/// محدد نوع العرض (للبيع / للإيجار)
class OfferTypeSelector extends StatelessWidget {
  final OfferType? selectedOfferType;
  final ValueChanged<OfferType?> onOfferTypeSelected;

  const OfferTypeSelector({
    super.key,
    required this.selectedOfferType,
    required this.onOfferTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OfferTypeButton(
            label: 'الكل',
            offerType: null,
            icon: Icons.all_inclusive,
            isSelected: selectedOfferType == null,
            onTap: () => onOfferTypeSelected(null),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OfferTypeButton(
            label: 'للبيع',
            offerType: OfferType.sale,
            icon: Icons.shopping_cart,
            isSelected: selectedOfferType == OfferType.sale,
            onTap: () => onOfferTypeSelected(OfferType.sale),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OfferTypeButton(
            label: 'للإيجار',
            offerType: OfferType.rent,
            icon: Icons.calendar_today,
            isSelected: selectedOfferType == OfferType.rent,
            onTap: () => onOfferTypeSelected(OfferType.rent),
          ),
        ),
      ],
    );
  }
}

/// زر نوع العرض
class OfferTypeButton extends StatelessWidget {
  final String label;
  final OfferType? offerType;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const OfferTypeButton({
    super.key,
    required this.label,
    required this.offerType,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? AppColors.transparent
                  : ColorUtils.withOpacity(AppColors.primary, 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.white : AppColors.primary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// شبكة المميزات
class AmenitiesGrid extends StatelessWidget {
  final List<String> selectedAmenities;
  final ValueChanged<String> onAmenityToggled;

  const AmenitiesGrid({
    super.key,
    required this.selectedAmenities,
    required this.onAmenityToggled,
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
      children: PropertyFilterData.amenities
          .map((amenity) => AmenityButton(
                amenity: amenity,
                isSelected: selectedAmenities.contains(amenity),
                onTap: () => onAmenityToggled(amenity),
              ))
          .toList(),
    );
  }
}

/// زر المميزة
class AmenityButton extends StatelessWidget {
  final String amenity;
  final bool isSelected;
  final VoidCallback onTap;

  const AmenityButton({
    super.key,
    required this.amenity,
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
                _getAmenityIcon(amenity),
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
              const SizedBox(height: 4),
              Text(
                amenity,
                style: TextStyle(
                  color:
                      isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getAmenityIcon(String amenity) {
    switch (amenity) {
      case 'مكيف':
        return Icons.ac_unit;
      case 'مفروش':
        return Icons.chair;
      case 'مطبخ':
        return Icons.kitchen;
      case 'مصعد':
        return Icons.elevator;
      case 'حديقة':
        return Icons.park;
      default:
        return Icons.check_box;
    }
  }
}

/// المميزات المتقدمة للعقارات
class AdvancedPropertyFeatures extends StatelessWidget {
  final FilterState state;
  final VoidCallback onUpdate;

  const AdvancedPropertyFeatures({
    super.key,
    required this.state,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FilterSectionTitle(title: 'معلومات العقار الأساسية'),
        FilterDropdown(
          value: state.propertyAge,
          items: PropertyFilterData.propertyAges,
          hint: 'عمر العقار',
          onChanged: (value) {
            state.propertyAge = value;
            onUpdate();
          },
        ),
        const SizedBox(height: 8),
        FilterDropdown(
          value: state.propertyDirection,
          items: PropertyFilterData.propertyDirections,
          hint: 'واجهة العقار',
          onChanged: (value) {
            state.propertyDirection = value;
            onUpdate();
          },
        ),
        const SizedBox(height: 8),
        FilterDropdown(
          value: state.streetWidth,
          items: PropertyFilterData.streetWidths,
          hint: 'عرض الشارع',
          onChanged: (value) {
            state.streetWidth = value;
            onUpdate();
          },
        ),
        const SizedBox(height: 16),

        const FilterSectionTitle(title: 'الغرف والمجالس'),
        FilterRangeSliderWithTitle(
          title: 'عدد المجالس',
          values: state.livingRoomsRange,
          min: 0,
          max: 5,
          onChanged: (values) {
            state.livingRoomsRange = values;
            onUpdate();
          },
          singularLabel: 'مجلس',
          pluralLabel: 'مجالس',
        ),
        const SizedBox(height: 8),
        FilterRangeSliderWithTitle(
          title: 'مجلس رجال/نساء',
          values: state.majlisRange,
          min: 0,
          max: 3,
          onChanged: (values) {
            state.majlisRange = values;
            onUpdate();
          },
          singularLabel: 'مجلس',
          pluralLabel: 'مجالس',
        ),
        const SizedBox(height: 8),
        FilterRangeSliderWithTitle(
          title: 'عدد المطابخ',
          values: state.kitchensRange,
          min: 1,
          max: 3,
          onChanged: (values) {
            state.kitchensRange = values;
            onUpdate();
          },
          singularLabel: 'مطبخ',
          pluralLabel: 'مطابخ',
        ),
        const SizedBox(height: 16),

        const FilterSectionTitle(title: 'المرافق الداخلية'),
        FilterSwitchTile(
          title: 'مصعد',
          value: state.hasElevator,
          onChanged: (value) {
            state.hasElevator = value;
            onUpdate();
          },
          icon: Icons.elevator,
        ),
        FilterSwitchTile(
          title: 'قبو',
          value: state.hasBasement,
          onChanged: (value) {
            state.hasBasement = value;
            onUpdate();
          },
          icon: Icons.foundation,
        ),
        FilterSwitchTile(
          title: 'غرفة سائق',
          value: state.hasDriverRoom,
          onChanged: (value) {
            state.hasDriverRoom = value;
            onUpdate();
          },
          icon: Icons.person,
        ),
        FilterSwitchTile(
          title: 'غرفة خادمة',
          value: state.hasMaidRoom,
          onChanged: (value) {
            state.hasMaidRoom = value;
            onUpdate();
          },
          icon: Icons.person_outline,
        ),
        FilterSwitchTile(
          title: 'غرفة حارس',
          value: state.hasGuardRoom,
          onChanged: (value) {
            state.hasGuardRoom = value;
            onUpdate();
          },
          icon: Icons.security,
        ),

        const SizedBox(height: 16),
        const FilterSectionTitle(title: 'المرافق الخارجية'),
        FilterSwitchTile(
          title: 'مدخل سيارة',
          value: state.hasCarEntrance,
          onChanged: (value) {
            state.hasCarEntrance = value;
            onUpdate();
          },
          icon: Icons.directions_car,
        ),
        FilterSwitchTile(
          title: 'حوش',
          value: state.hasYard,
          onChanged: (value) {
            state.hasYard = value;
            onUpdate();
          },
          icon: Icons.yard,
        ),
        FilterSwitchTile(
          title: 'خيمة',
          value: state.hasTent,
          onChanged: (value) {
            state.hasTent = value;
            onUpdate();
          },
          icon: Icons.festival,
        ),
        FilterSwitchTile(
          title: 'مسبح',
          value: state.hasSwimmingPool,
          onChanged: (value) {
            state.hasSwimmingPool = value;
            onUpdate();
          },
          icon: Icons.pool,
        ),
        FilterSwitchTile(
          title: 'بئر ماء',
          value: state.hasWellWater,
          onChanged: (value) {
            state.hasWellWater = value;
            onUpdate();
          },
          icon: Icons.water_drop,
        ),

        const SizedBox(height: 16),
        const FilterSectionTitle(title: 'التجهيزات'),
        FilterSwitchTile(
          title: 'مكيفات',
          value: state.hasAirConditioners,
          onChanged: (value) {
            state.hasAirConditioners = value;
            onUpdate();
          },
          icon: Icons.ac_unit,
        ),
        FilterSwitchTile(
          title: 'مطبخ راكب',
          value: state.hasKitchenCabinets,
          onChanged: (value) {
            state.hasKitchenCabinets = value;
            onUpdate();
          },
          icon: Icons.kitchen,
        ),
        FilterSwitchTile(
          title: 'تكييف مركزي',
          value: state.hasCentralAC,
          onChanged: (value) {
            state.hasCentralAC = value;
            onUpdate();
          },
          icon: Icons.hvac,
        ),
        FilterSwitchTile(
          title: 'إضاءة حديقة',
          value: state.hasGardenLighting,
          onChanged: (value) {
            state.hasGardenLighting = value;
            onUpdate();
          },
          icon: Icons.lightbulb,
        ),

        const SizedBox(height: 16),
        const FilterSectionTitle(title: 'أنظمة الأمان'),
        FilterSwitchTile(
          title: 'انتركم',
          value: state.hasIntercom,
          onChanged: (value) {
            state.hasIntercom = value;
            onUpdate();
          },
          icon: Icons.phone_in_talk,
        ),
        FilterSwitchTile(
          title: 'بوابة كهربائية',
          value: state.hasElectricGate,
          onChanged: (value) {
            state.hasElectricGate = value;
            onUpdate();
          },
          icon: Icons.electric_bolt,
        ),
        FilterSwitchTile(
          title: 'نظام إنذار حريق',
          value: state.hasFireAlarm,
          onChanged: (value) {
            state.hasFireAlarm = value;
            onUpdate();
          },
          icon: Icons.fire_extinguisher,
        ),
        FilterSwitchTile(
          title: 'كاميرات مراقبة',
          value: state.hasSecurityCameras,
          onChanged: (value) {
            state.hasSecurityCameras = value;
            onUpdate();
          },
          icon: Icons.videocam,
        ),
      ],
    );
  }
}
