import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class MapFilterScreen extends StatefulWidget {
  final bool isRealEstate; // لتحديد نوع الفلتر (عقارات/سيارات)

  const MapFilterScreen({
    required this.isRealEstate, super.key,
  });

  // دالة مساعدة لعرض الفلتر كـ popup
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required bool isRealEstate,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, // تصغير الحجم إلى نصف الشاشة
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, scrollController) => MapFilterScreen(
          isRealEstate: isRealEstate,
        ),
      ),
    );
  }

  @override
  State<MapFilterScreen> createState() => _MapFilterScreenState();
}

class _MapFilterScreenState extends State<MapFilterScreen> {
  RangeValues _priceRange = const RangeValues(0, 10000000);
  RangeValues _areaRange = const RangeValues(0, 1000);
  RangeValues _yearRange = const RangeValues(2000, 2024);
  RangeValues _kmRange = const RangeValues(0, 300000);
  String _selectedPropertyType = 'شقة';
  String? _selectedCity;
  String? _selectedCarMake;
  String? _selectedCarType;
  String? _selectedFuelType;
  String? _selectedTransmission;
  final List<String> _selectedAmenities = [];
  final List<String> _selectedCarFeatures = [];
  bool _hasParking = false;
  bool _hasPool = false;
  bool _isNew = false;
  bool _isWarranty = false;
  bool _isInsurance = false;
  bool _isImported = false;

  // قوائم للعقارات
  final List<String> _propertyTypes = ['شقة', 'فيلا', 'عمارة', 'أرض', 'محل تجاري'];
  final List<String> _cities = ['الرياض', 'جدة', 'الدمام', 'مكة', 'المدينة'];
  final List<String> _amenities = ['مكيف', 'مفروش', 'مطبخ', 'مصعد', 'حديقة'];

  // قوائم للسيارات
  final List<String> _carMakes = ['تويوتا', 'هونداي', 'فورد', 'نيسان', 'كيا', 'شفروليه', 'مرسيدس', 'بي ام دبليو', 'لكزس', 'جي إم سي'];
  final List<String> _carTypes = ['سيدان', 'دفع رباعي', 'بيك اب', 'فان', 'كوبيه', 'هاتشباك'];
  final List<String> _fuelTypes = ['بنزين', 'ديزل', 'هايبرد', 'كهربائي'];
  final List<String> _transmissionTypes = ['أوتوماتيك', 'يدوي'];
  final List<String> _carFeatures = [
    'نظام ملاحة',
    'كاميرا خلفية',
    'حساسات',
    'فتحة سقف',
    'مثبت سرعة',
    'بلوتوث',
    'شاشة لمس',
    'تحكم بالمقود'
  ];

  // إضافة متغيرات جديدة للتفاعل
  bool _showAdvancedOptions = false;
  int _selectedCount = 0;
  String? _selectedDistrict;
  RangeValues _roomsRange = const RangeValues(1, 10);
  RangeValues _bathroomsRange = const RangeValues(1, 5);
  String? _selectedCarColor;
  String? _selectedCarCondition;

  // إضافة قوائم جديدة
  final List<String> _districts = ['شمال', 'جنوب', 'شرق', 'غرب', 'وسط المدينة'];
  final List<String> _carColors = ['أبيض', 'أسود', 'فضي', 'أحمر', 'أزرق', 'رمادي'];
  final List<String> _carConditions = ['جديد', 'كالجديد', 'مستعمل - ممتاز', 'مستعمل - جيد', 'يحتاج صيانة'];

  // إضافة متغيرات جديدة للعقارات
  String? _selectedDirection; // اتجاه العقار
  String? _selectedAge; // عمر العقار
  bool _hasGarden = false; // حديقة
  bool _hasRoofTop = false; // سطح خاص
  bool _hasGym = false; // صالة رياضية
  bool _hasStorage = false; // غرفة تخزين
  bool _hasSecurity = false; // أمن وحراسة
  bool _hasIntercom = false; // انتركم
  bool _hasBasement = false; // قبو
  bool _hasDriverRoom = false; // غرفة سائق
  bool _hasMaidRoom = false; // غرفة خادمة
  bool _hasSwimmingPool = false; // مسبح
  bool _isFirstOwner = false; // المالك الأول
  bool _isRegisteredInNetwork = false; // مسجل في الشبكة
  bool _isMortgageAvailable = false; // متاح للرهن
  bool _isNegotiable = false; // قابل للتفاوض

  // إضافة متغيرات جديدة للسيارات
  String? _selectedEngine; // حجم المحرك
  String? _selectedInteriorColor; // لون الداخلية
  String? _selectedDriveType; // نوع الدفع
  bool _hasServiceHistory = false; // سجل صيانة
  bool _hasAccidentHistory = false; // سجل حوادث
  bool _isGccSpecs = false; // مواصفات خليجية
  bool _hasCustomNumber = false; // رقم مميز
  bool _isAgencyMaintained = false; // صيانة وكالة
  bool _isUnderWarranty = false; // تحت الضمان
  bool _isExportable = false; // قابل للتصدير
  bool _isFirstOwnerCar = false; // المالك الأول
  bool _isNegotiableCar = false; // قابل للتفاوض

  // إضافة قوائم جديدة للعقارات
  final List<String> _propertyAges = [
    'جديد',
    'أقل من سنة',
    '1-3 سنوات',
    '3-5 سنوات',
    '5-10 سنوات',
    '10-15 سنة',
    'أكثر من 15 سنة'
  ];

  final List<String> _propertyDirections = [
    'شمالي',
    'جنوبي',
    'شرقي',
    'غربي',
    'شمالي شرقي',
    'شمالي غربي',
    'جنوبي شرقي',
    'جنوبي غربي'
  ];

  final List<String> _streetWidths = [
    'أقل من 10 متر',
    '10-15 متر',
    '15-20 متر',
    '20-30 متر',
    'أكثر من 30 متر'
  ];

  // إضافة متغيرات جديدة للسيارات
  String? _selectedBodyStyle; // شكل الهيكل
  String? _selectedSeatsCount; // عدد المقاعد
  String? _selectedCylinders; // عدد السلندرات
  String? _selectedTrimLevel; // مستوى الفئة
  bool _hasPanoramicRoof = false; // سقف بانورامي
  bool _hasAdaptiveCruiseControl = false; // مثبت سرعة ذكي
  bool _hasBlindSpotMonitoring = false; // نظام مراقبة النقاط العمياء
  bool _hasLaneAssist = false; // نظام المساعدة في الحارة
  bool _has360Camera = false; // كاميرا 360
  bool _hasHeadUpDisplay = false; // شاشة عرض أمامية
  bool _hasWirelessCharging = false; // شحن لاسلكي
  bool _hasRemoteStart = false; // تشغيل عن بعد
  bool _hasVentilatedSeats = false; // مقاعد مهواة
  bool _hasMemorySeats = false; // مقاعد بذاكرة
  bool _hasMassageSeats = false; // مقاعد مساج
  bool _hasThirdRow = false; // صف ثالث

  // إضافة قوائم جديدة للسيارات
  final List<String> _bodyStyles = [
    'سيدان',
    'هاتشباك',
    'كوبيه',
    'كروس أوفر',
    'دفع رباعي',
    'بيك أب',
    'فان',
    'واجن'
  ];

  final List<String> _seatsCount = [
    '2 مقاعد',
    '4 مقاعد',
    '5 مقاعد',
    '6 مقاعد',
    '7 مقاعد',
    '8 مقاعد',
    'أكثر من 8'
  ];

  final List<String> _cylinders = [
    '3 سلندر',
    '4 سلندر',
    '6 سلندر',
    '8 سلندر',
    '10 سلندر',
    '12 سلندر'
  ];

  final List<String> _trimLevels = [
    'ستاندرد',
    'فل',
    'نص فل',
    'فل كامل',
    'بريميوم',
    'بلاتينيوم',
    'سبورت'
  ];

  // إضافة متغيرات جديدة للعقارات
  RangeValues _livingRoomsRange = const RangeValues(0, 5); // المجالس
  RangeValues _majlisRange = const RangeValues(0, 3); // مجلس رجال/نساء
  RangeValues _kitchensRange = const RangeValues(1, 3); // المطابخ
  String? _propertyAge; // عمر العقار
  String? _propertyDirection; // اتجاه العقار
  String? _streetWidth; // عرض الشارع
  bool _hasElevator = false; // مصعد
  bool _hasCarEntrance = false; // مدخل سيارة
  bool _hasYard = false; // حوش
  bool _hasTent = false; // خيمة
  bool _hasGuardRoom = false; // غرفة حارس
  bool _hasWellWater = false; // بئر ماء
  bool _hasAirConditioners = false; // مكيفات
  bool _hasKitchenCabinets = false; // مطبخ راكب
  bool _hasCentralAC = false; // تكييف مركزي
  bool _hasGardenLighting = false; // إضاءة حديقة
  bool _hasElectricGate = false; // بوابة كهربائية
  bool _hasFireAlarm = false; // نظام إنذار حريق
  bool _hasSecurityCameras = false; // كاميرات مراقبة

  bool _has360View = false;
  bool _hasVirtualTour = false;
  bool _hasInteriorView = false; // للسيارات فقط

  @override
  void initState() {
    super.initState();
    _updateSelectedCount();
  }

  void _updateSelectedCount() {
    setState(() {
      if (widget.isRealEstate) {
        _selectedCount = _selectedAmenities.length +
            (_hasParking ? 1 : 0) +
            (_hasPool ? 1 : 0) +
            (_isNew ? 1 : 0) +
            (_selectedCity != null ? 1 : 0) +
            (_selectedDistrict != null ? 1 : 0);
      } else {
        _selectedCount = _selectedCarFeatures.length +
            (_isWarranty ? 1 : 0) +
            (_isInsurance ? 1 : 0) +
            (_isImported ? 1 : 0) +
            (_selectedCarMake != null ? 1 : 0) +
            (_selectedCarType != null ? 1 : 0) +
            (_selectedFuelType != null ? 1 : 0) +
            (_selectedTransmission != null ? 1 : 0) +
            (_selectedCity != null ? 1 : 0) +
            (_selectedCarColor != null ? 1 : 0) +
            (_selectedCarCondition != null ? 1 : 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isRealEstate ? 'فلترة العقارات' : 'فلترة السيارات',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedCount > 0)
                      Text(
                        'الفلاتر النشطة: $_selectedCount',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _showAdvancedOptions = !_showAdvancedOptions;
                        });
                      },
                      tooltip: _showAdvancedOptions ? 'عرض أقل' : 'خيارات متقدمة',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isRealEstate) ...[
                    // فلاتر العقارات الأساسية
                    _buildSectionTitle('نوع العقار'),
                    _buildPropertyTypesGrid(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('نطاق السعر'),
                    _buildPriceRangeSlider(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('المدينة والحي'),
                    _buildLocationSelection(),
                    const SizedBox(height: 24),

                    if (_showAdvancedOptions) ...[
                      _buildSectionTitle('المساحة'),
                      _buildAreaRangeSlider(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('عدد الغرف'),
                      _buildRoomsRangeSlider(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('دورات المياه'),
                      _buildBathroomsRangeSlider(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('المميزات'),
                      _buildAmenitiesGrid(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('مميزات إضافية'),
                      _buildAdvancedPropertyFeatures(),
                    ],
                  ] else ...[
                    // فلاتر السيارات الأساسية
                    _buildSectionTitle('معلومات السيارة'),
                    _buildCarBasicInfo(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('السعر وسنة الصنع'),
                    _buildCarPriceAndYear(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('الموقع'),
                    _buildLocationSelection(),
                    const SizedBox(height: 24),

                    if (_showAdvancedOptions) ...[
                      _buildSectionTitle('المواصفات الفنية'),
                      _buildCarTechnicalSpecs(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('حالة السيارة'),
                      _buildCarConditionSelection(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('المميزات'),
                      _buildCarFeaturesGrid(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('معلومات إضافية'),
                      _buildAdvancedCarFeatures(),
                    ],
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.withOpacity(AppColors.text, 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_selectedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'تم تحديد $_selectedCount من الفلاتر',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _resetFilters();
                          _updateSelectedCount();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة تعيين'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _applyFilters();
                          _updateSelectedCount();
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('تطبيق'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPropertyTypesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: _propertyTypes.map((type) => _buildPropertyTypeButton(type)).toList(),
    );
  }

  Widget _buildPropertyTypeButton(String type) {
    final isSelected = _selectedPropertyType == type;
    return Material(
      color: isSelected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPropertyType = type;
            _updateSelectedCount();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.transparent : ColorUtils.withOpacity(AppColors.primary, 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getPropertyTypeIcon(type),
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(height: 4),
              Text(
                type,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
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

  Widget _buildLocationSelection() {
    return Column(
      children: [
        _buildDropdown(
          value: _selectedCity,
          items: _cities,
          hint: 'اختر المدينة',
          onChanged: (value) {
            setState(() {
              _selectedCity = value;
              _selectedDistrict = null;
              _updateSelectedCount();
            });
          },
        ),
        if (_selectedCity != null) ...[
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedDistrict,
            items: _districts,
            hint: 'اختر الحي',
            onChanged: (value) {
              setState(() {
                _selectedDistrict = value;
                _updateSelectedCount();
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildRoomsRangeSlider() {
    return Column(
      children: [
        RangeSlider(
          values: _roomsRange,
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: AppColors.primary,
          inactiveColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
          labels: RangeLabels(
            '${_roomsRange.start.round()} غرفة',
            '${_roomsRange.end.round()} غرف',
          ),
          onChanged: (values) => setState(() => _roomsRange = values),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'غرفة واحدة',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              '10 غرف',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBathroomsRangeSlider() {
    return Column(
      children: [
        RangeSlider(
          values: _bathroomsRange,
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: AppColors.primary,
          inactiveColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
          labels: RangeLabels(
            '${_bathroomsRange.start.round()} حمام',
            '${_bathroomsRange.end.round()} حمامات',
          ),
          onChanged: (values) => setState(() => _bathroomsRange = values),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'حمام واحد',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              '5 حمامات',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmenitiesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: _amenities.map((amenity) => _buildAmenityButton(amenity)).toList(),
    );
  }

  Widget _buildAmenityButton(String amenity) {
    final isSelected = _selectedAmenities.contains(amenity);
    return Material(
      color: isSelected ? ColorUtils.withOpacity(AppColors.primary, 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedAmenities.remove(amenity);
            } else {
              _selectedAmenities.add(amenity);
            }
            _updateSelectedCount();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getAmenityIcon(amenity),
                color: isSelected ? AppColors.primary : Colors.grey[600],
              ),
              const SizedBox(height: 4),
              Text(
                amenity,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildAdvancedPropertyFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('معلومات العقار الأساسية'),
        _buildDropdown(
          value: _propertyAge,
          items: _propertyAges,
          hint: 'عمر العقار',
          onChanged: (value) => setState(() {
            _propertyAge = value;
            _updateSelectedCount();
          }),
        ),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _propertyDirection,
          items: _propertyDirections,
          hint: 'واجهة العقار',
          onChanged: (value) => setState(() {
            _propertyDirection = value;
            _updateSelectedCount();
          }),
        ),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _streetWidth,
          items: _streetWidths,
          hint: 'عرض الشارع',
          onChanged: (value) => setState(() {
            _streetWidth = value;
            _updateSelectedCount();
          }),
        ),
        const SizedBox(height: 16),

        _buildSectionTitle('الغرف والمجالس'),
        _buildRangeSliderWithTitle(
          'عدد المجالس',
          _livingRoomsRange,
          0,
          5,
          (values) => setState(() => _livingRoomsRange = values),
          'مجلس',
          'مجالس'
        ),
        const SizedBox(height: 8),
        _buildRangeSliderWithTitle(
          'مجلس رجال/نساء',
          _majlisRange,
          0,
          3,
          (values) => setState(() => _majlisRange = values),
          'مجلس',
          'مجالس'
        ),
        const SizedBox(height: 8),
        _buildRangeSliderWithTitle(
          'عدد المطابخ',
          _kitchensRange,
          1,
          3,
          (values) => setState(() => _kitchensRange = values),
          'مطبخ',
          'مطابخ'
        ),
        const SizedBox(height: 16),

        _buildSectionTitle('المرافق الداخلية'),
        _buildSwitchTile('مصعد', _hasElevator, (value) => setState(() {
          _hasElevator = value;
          _updateSelectedCount();
        }), Icons.elevator),
        _buildSwitchTile('قبو', _hasBasement, (value) => setState(() {
          _hasBasement = value;
          _updateSelectedCount();
        }), Icons.foundation),
        _buildSwitchTile('غرفة سائق', _hasDriverRoom, (value) => setState(() {
          _hasDriverRoom = value;
          _updateSelectedCount();
        }), Icons.person),
        _buildSwitchTile('غرفة خادمة', _hasMaidRoom, (value) => setState(() {
          _hasMaidRoom = value;
          _updateSelectedCount();
        }), Icons.person_outline),
        _buildSwitchTile('غرفة حارس', _hasGuardRoom, (value) => setState(() {
          _hasGuardRoom = value;
          _updateSelectedCount();
        }), Icons.security),

        const SizedBox(height: 16),
        _buildSectionTitle('المرافق الخارجية'),
        _buildSwitchTile('مدخل سيارة', _hasCarEntrance, (value) => setState(() {
          _hasCarEntrance = value;
          _updateSelectedCount();
        }), Icons.directions_car),
        _buildSwitchTile('حوش', _hasYard, (value) => setState(() {
          _hasYard = value;
          _updateSelectedCount();
        }), Icons.yard),
        _buildSwitchTile('خيمة', _hasTent, (value) => setState(() {
          _hasTent = value;
          _updateSelectedCount();
        }), Icons.festival),
        _buildSwitchTile('مسبح', _hasSwimmingPool, (value) => setState(() {
          _hasSwimmingPool = value;
          _updateSelectedCount();
        }), Icons.pool),
        _buildSwitchTile('بئر ماء', _hasWellWater, (value) => setState(() {
          _hasWellWater = value;
          _updateSelectedCount();
        }), Icons.water_drop),

        const SizedBox(height: 16),
        _buildSectionTitle('التجهيزات'),
        _buildSwitchTile('مكيفات', _hasAirConditioners, (value) => setState(() {
          _hasAirConditioners = value;
          _updateSelectedCount();
        }), Icons.ac_unit),
        _buildSwitchTile('مطبخ راكب', _hasKitchenCabinets, (value) => setState(() {
          _hasKitchenCabinets = value;
          _updateSelectedCount();
        }), Icons.kitchen),
        _buildSwitchTile('تكييف مركزي', _hasCentralAC, (value) => setState(() {
          _hasCentralAC = value;
          _updateSelectedCount();
        }), Icons.hvac),
        _buildSwitchTile('إضاءة حديقة', _hasGardenLighting, (value) => setState(() {
          _hasGardenLighting = value;
          _updateSelectedCount();
        }), Icons.lightbulb),

        const SizedBox(height: 16),
        _buildSectionTitle('أنظمة الأمان'),
        _buildSwitchTile('انتركم', _hasIntercom, (value) => setState(() {
          _hasIntercom = value;
          _updateSelectedCount();
        }), Icons.phone_in_talk),
        _buildSwitchTile('بوابة كهربائية', _hasElectricGate, (value) => setState(() {
          _hasElectricGate = value;
          _updateSelectedCount();
        }), Icons.electric_bolt),
        _buildSwitchTile('نظام إنذار حريق', _hasFireAlarm, (value) => setState(() {
          _hasFireAlarm = value;
          _updateSelectedCount();
        }), Icons.fire_extinguisher),
        _buildSwitchTile('كاميرات مراقبة', _hasSecurityCameras, (value) => setState(() {
          _hasSecurityCameras = value;
          _updateSelectedCount();
        }), Icons.videocam),
      ],
    );
  }

  Widget _buildRangeSliderWithTitle(
    String title,
    RangeValues values,
    double min,
    double max,
    ValueChanged<RangeValues> onChanged,
    String singularLabel,
    String pluralLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14)),
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: max.toInt(),
          activeColor: AppColors.primary,
          inactiveColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
          labels: RangeLabels(
            '${values.start.round()} $singularLabel',
            '${values.end.round()} $pluralLabel',
          ),
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$min $singularLabel',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              '${max.toInt()} $pluralLabel',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCarBasicInfo() {
    return Column(
      children: [
        _buildDropdown(
          value: _selectedCarMake,
          items: _carMakes,
          hint: 'اختر الشركة المصنعة',
          onChanged: (value) {
            setState(() {
              _selectedCarMake = value;
              _updateSelectedCount();
            });
          },
        ),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedCarType,
          items: _carTypes,
          hint: 'اختر نوع السيارة',
          onChanged: (value) {
            setState(() {
              _selectedCarType = value;
              _updateSelectedCount();
            });
          },
        ),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedCarColor,
          items: _carColors,
          hint: 'اختر لون السيارة',
          onChanged: (value) {
            setState(() {
              _selectedCarColor = value;
              _updateSelectedCount();
            });
          },
        ),
      ],
    );
  }

  Widget _buildCarPriceAndYear() {
    return Column(
      children: [
        _buildPriceRangeSlider(),
        const SizedBox(height: 16),
        _buildYearRangeSlider(),
      ],
    );
  }

  Widget _buildCarTechnicalSpecs() {
    return Column(
      children: [
        _buildDropdown(
          value: _selectedFuelType,
          items: _fuelTypes,
          hint: 'اختر نوع الوقود',
          onChanged: (value) {
            setState(() {
              _selectedFuelType = value;
              _updateSelectedCount();
            });
          },
        ),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedTransmission,
          items: _transmissionTypes,
          hint: 'اختر نوع ناقل الحركة',
          onChanged: (value) {
            setState(() {
              _selectedTransmission = value;
              _updateSelectedCount();
            });
          },
        ),
        const SizedBox(height: 16),
        _buildKilometersRangeSlider(),
      ],
    );
  }

  Widget _buildCarConditionSelection() {
    return _buildDropdown(
      value: _selectedCarCondition,
      items: _carConditions,
      hint: 'اختر حالة السيارة',
      onChanged: (value) {
        setState(() {
          _selectedCarCondition = value;
          _updateSelectedCount();
        });
      },
    );
  }

  Widget _buildCarFeaturesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: _carFeatures.map((feature) => _buildCarFeatureButton(feature)).toList(),
    );
  }

  Widget _buildCarFeatureButton(String feature) {
    final isSelected = _selectedCarFeatures.contains(feature);
    return Material(
      color: isSelected ? ColorUtils.withOpacity(AppColors.primary, 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedCarFeatures.remove(feature);
            } else {
              _selectedCarFeatures.add(feature);
            }
            _updateSelectedCount();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getCarFeatureIcon(feature),
                color: isSelected ? AppColors.primary : Colors.grey[600],
              ),
              const SizedBox(height: 4),
              Text(
                feature,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.black87,
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

  Widget _buildAdvancedCarFeatures() {
    return Column(
      children: [
        _buildSectionTitle('مواصفات السيارة الأساسية'),
        _buildDropdown(
          value: _selectedBodyStyle,
          items: _bodyStyles,
          hint: 'شكل الهيكل',
          onChanged: (value) => setState(() {
            _selectedBodyStyle = value;
            _updateSelectedCount();
          }),
        ),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedSeatsCount,
          items: _seatsCount,
          hint: 'عدد المقاعد',
          onChanged: (value) => setState(() {
            _selectedSeatsCount = value;
            _updateSelectedCount();
          }),
        ),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedCylinders,
          items: _cylinders,
          hint: 'عدد السلندرات',
          onChanged: (value) => setState(() {
            _selectedCylinders = value;
            _updateSelectedCount();
          }),
        ),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedTrimLevel,
          items: _trimLevels,
          hint: 'مستوى الفئة',
          onChanged: (value) => setState(() {
            _selectedTrimLevel = value;
            _updateSelectedCount();
          }),
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('أنظمة السلامة والمساعدة'),
        _buildSwitchTile(
          'كاميرا 360',
          _has360Camera,
          (value) => setState(() {
            _has360Camera = value;
            _updateSelectedCount();
          }),
          Icons.camera
        ),
        _buildSwitchTile(
          'سقف بانورامي',
          _hasPanoramicRoof,
          (value) => setState(() {
            _hasPanoramicRoof = value;
            _updateSelectedCount();
          }),
          Icons.wb_sunny
        ),
        _buildSwitchTile(
          'شاشة عرض أمامية',
          _hasHeadUpDisplay,
          (value) => setState(() {
            _hasHeadUpDisplay = value;
            _updateSelectedCount();
          }),
          Icons.display_settings
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('الكماليات والراحة'),
        _buildSwitchTile(
          'شحن لاسلكي',
          _hasWirelessCharging,
          (value) => setState(() {
            _hasWirelessCharging = value;
            _updateSelectedCount();
          }),
          Icons.battery_charging_full
        ),
        _buildSwitchTile(
          'تشغيل عن بعد',
          _hasRemoteStart,
          (value) => setState(() {
            _hasRemoteStart = value;
            _updateSelectedCount();
          }),
          Icons.key
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('المقاعد'),
        _buildSwitchTile('مقاعد مهواة', _hasVentilatedSeats, (value) => setState(() {
          _hasVentilatedSeats = value;
          _updateSelectedCount();
        }), Icons.airline_seat_recline_extra),
        _buildSwitchTile('مقاعد بذاكرة', _hasMemorySeats, (value) => setState(() {
          _hasMemorySeats = value;
          _updateSelectedCount();
        }), Icons.chair),
        _buildSwitchTile('مقاعد مساج', _hasMassageSeats, (value) => setState(() {
          _hasMassageSeats = value;
          _updateSelectedCount();
        }), Icons.chair_alt),
        _buildSwitchTile('صف ثالث', _hasThirdRow, (value) => setState(() {
          _hasThirdRow = value;
          _updateSelectedCount();
        }), Icons.event_seat),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged, [IconData? icon]) {
    return SwitchListTile(
      title: Row(
        children: [
          Icon(
            icon ?? Icons.check_box,
            size: 20,
            color: value ? AppColors.primary : Colors.grey[600]
          ),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }

  Widget _buildPriceRangeSlider() {
    return Column(
      children: [
        RangeSlider(
          values: _priceRange,
          max: 10000000,
          divisions: 100,
          activeColor: AppColors.primary,
          inactiveColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
          labels: RangeLabels(
            '${_priceRange.start.round()} ريال',
            '${_priceRange.end.round()} ريال',
          ),
          onChanged: (values) => setState(() => _priceRange = values),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0 ريال',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              '10,000,000 ريال',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAreaRangeSlider() {
    return Column(
      children: [
        RangeSlider(
          values: _areaRange,
          max: 1000,
          divisions: 50,
          activeColor: AppColors.primary,
          inactiveColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
          labels: RangeLabels(
            '${_areaRange.start.round()} م²',
            '${_areaRange.end.round()} م²',
          ),
          onChanged: (values) => setState(() => _areaRange = values),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0 م²',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              '1000 م²',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYearRangeSlider() {
    return Column(
      children: [
        RangeSlider(
          values: _yearRange,
          min: 2000,
          max: 2024,
          divisions: 24,
          activeColor: AppColors.primary,
          inactiveColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
          labels: RangeLabels(
            _yearRange.start.round().toString(),
            _yearRange.end.round().toString(),
          ),
          onChanged: (values) => setState(() => _yearRange = values),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '2000',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              '2024',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKilometersRangeSlider() {
    return Column(
      children: [
        RangeSlider(
          values: _kmRange,
          max: 300000,
          divisions: 60,
          activeColor: AppColors.primary,
          inactiveColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
          labels: RangeLabels(
            '${_kmRange.start.round()} كم',
            '${_kmRange.end.round()} كم',
          ),
          onChanged: (values) => setState(() => _kmRange = values),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0 كم',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              '300,000 كم',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  // إضافة دالة بناء القائمة المنسدلة
  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: const TextStyle(fontSize: 14),
          ),
        )).toList(),
        onChanged: onChanged,
        hint: Text(
          hint,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
        isExpanded: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _priceRange = const RangeValues(0, 10000000);
      _areaRange = const RangeValues(0, 1000);
      _yearRange = const RangeValues(2000, 2024);
      _kmRange = const RangeValues(0, 300000);
      _selectedPropertyType = 'شقة';
      _selectedCity = null;
      _selectedCarMake = null;
      _selectedCarType = null;
      _selectedFuelType = null;
      _selectedTransmission = null;
      _selectedAmenities.clear();
      _selectedCarFeatures.clear();
      _hasParking = false;
      _hasPool = false;
      _isNew = false;
      _isWarranty = false;
      _isInsurance = false;
      _isImported = false;

      // إعادة تعيين القيم الجديدة للعقارات
      _selectedDirection = null;
      _selectedAge = null;
      _hasGarden = false;
      _hasRoofTop = false;
      _hasGym = false;
      _hasStorage = false;
      _hasSecurity = false;
      _hasIntercom = false;
      _hasBasement = false;
      _hasDriverRoom = false;
      _hasMaidRoom = false;
      _hasSwimmingPool = false;
      _isFirstOwner = false;
      _isRegisteredInNetwork = false;
      _isMortgageAvailable = false;
      _isNegotiable = false;

      // إعادة تعيين القيم الجديدة للسيارات
      _selectedEngine = null;
      _selectedInteriorColor = null;
      _selectedDriveType = null;
      _hasServiceHistory = false;
      _hasAccidentHistory = false;
      _isGccSpecs = false;
      _hasCustomNumber = false;
      _isAgencyMaintained = false;
      _isUnderWarranty = false;
      _isExportable = false;
      _isFirstOwnerCar = false;
      _isNegotiableCar = false;

      // إعادة تعيين القيم الجديدة للسيارات
      _selectedBodyStyle = null;
      _selectedSeatsCount = null;
      _selectedCylinders = null;
      _selectedTrimLevel = null;
      _hasPanoramicRoof = false;
      _hasAdaptiveCruiseControl = false;
      _hasBlindSpotMonitoring = false;
      _hasLaneAssist = false;
      _has360Camera = false;
      _hasHeadUpDisplay = false;
      _hasWirelessCharging = false;
      _hasRemoteStart = false;
      _hasVentilatedSeats = false;
      _hasMemorySeats = false;
      _hasMassageSeats = false;
      _hasThirdRow = false;

      // إعادة تعيين القيم الجديدة للعقارات
      _livingRoomsRange = const RangeValues(0, 5);
      _majlisRange = const RangeValues(0, 3);
      _kitchensRange = const RangeValues(1, 3);
      _propertyAge = null;
      _propertyDirection = null;
      _streetWidth = null;
      _hasElevator = false;
      _hasCarEntrance = false;
      _hasYard = false;
      _hasTent = false;
      _hasGuardRoom = false;
      _hasWellWater = false;
      _hasAirConditioners = false;
      _hasKitchenCabinets = false;
      _hasCentralAC = false;
      _hasGardenLighting = false;
      _hasElectricGate = false;
      _hasFireAlarm = false;
      _hasSecurityCameras = false;

      _has360View = false;
      _hasVirtualTour = false;
      _hasInteriorView = false;
    });
  }

  void _applyFilters() {
    final result = widget.isRealEstate
        ? {
            'propertyType': _selectedPropertyType,
            'priceRange': _priceRange,
            'areaRange': _areaRange,
            'city': _selectedCity,
            'amenities': _selectedAmenities,
            'hasParking': _hasParking,
            'hasPool': _hasPool,
            'isNew': _isNew,
            'direction': _selectedDirection,
            'age': _selectedAge,
            'hasGarden': _hasGarden,
            'hasRoofTop': _hasRoofTop,
            'hasGym': _hasGym,
            'hasStorage': _hasStorage,
            'hasSecurity': _hasSecurity,
            'hasIntercom': _hasIntercom,
            'hasBasement': _hasBasement,
            'hasDriverRoom': _hasDriverRoom,
            'hasMaidRoom': _hasMaidRoom,
            'hasSwimmingPool': _hasSwimmingPool,
            'isFirstOwner': _isFirstOwner,
            'isRegisteredInNetwork': _isRegisteredInNetwork,
            'isMortgageAvailable': _isMortgageAvailable,
            'isNegotiable': _isNegotiable,
            'has360View': _has360View,
            'hasVirtualTour': _hasVirtualTour,
            'hasInteriorView': _hasInteriorView,
          }
        : {
            'carMake': _selectedCarMake,
            'carType': _selectedCarType,
            'yearRange': _yearRange,
            'priceRange': _priceRange,
            'kmRange': _kmRange,
            'fuelType': _selectedFuelType,
            'transmission': _selectedTransmission,
            'city': _selectedCity,
            'features': _selectedCarFeatures,
            'isWarranty': _isWarranty,
            'isInsurance': _isInsurance,
            'isImported': _isImported,
            'engineSize': _selectedEngine,
            'interiorColor': _selectedInteriorColor,
            'driveType': _selectedDriveType,
            'hasServiceHistory': _hasServiceHistory,
            'hasAccidentHistory': _hasAccidentHistory,
            'isGccSpecs': _isGccSpecs,
            'hasCustomNumber': _hasCustomNumber,
            'isAgencyMaintained': _isAgencyMaintained,
            'isUnderWarranty': _isUnderWarranty,
            'isExportable': _isExportable,
            'isFirstOwnerCar': _isFirstOwnerCar,
            'isNegotiableCar': _isNegotiableCar,
            'bodyStyle': _selectedBodyStyle,
            'seatsCount': _selectedSeatsCount,
            'cylinders': _selectedCylinders,
            'trimLevel': _selectedTrimLevel,
            'hasPanoramicRoof': _hasPanoramicRoof,
            'hasAdaptiveCruiseControl': _hasAdaptiveCruiseControl,
            'hasBlindSpotMonitoring': _hasBlindSpotMonitoring,
            'hasLaneAssist': _hasLaneAssist,
            'has360Camera': _has360Camera,
            'hasHeadUpDisplay': _hasHeadUpDisplay,
            'hasWirelessCharging': _hasWirelessCharging,
            'hasRemoteStart': _hasRemoteStart,
            'hasVentilatedSeats': _hasVentilatedSeats,
            'hasMemorySeats': _hasMemorySeats,
            'hasMassageSeats': _hasMassageSeats,
            'hasThirdRow': _hasThirdRow,
            'has360View': _has360View,
            'hasVirtualTour': _hasVirtualTour,
            'hasInteriorView': _hasInteriorView,
          };
    Navigator.pop(context, result);
  }
}