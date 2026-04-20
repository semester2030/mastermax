import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_state.dart';
import '../../auth/utils/listing_vertical_guard.dart';
import '../../map/providers/map_state.dart';
import '../models/property_model.dart';
import '../models/property_type.dart';
import '../models/property_room_details.dart';
import '../providers/property_provider.dart';
import '../services/property_image_service.dart';
import '../services/property_location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/property_form_helpers.dart';
import '../widgets/property_progress_indicator.dart';
import '../widgets/property_image_picker.dart';
import '../widgets/property_type_selector.dart';
import '../widgets/offer_type_selector.dart';
import '../widgets/property_room_details_section.dart';
import '../widgets/property_saudi_details_section.dart';
import '../widgets/property_features_section.dart';
import '../widgets/property_location_picker.dart';
import '../widgets/property_360_view_section.dart';
import '../widgets/property_rental_details_section.dart';

class AddPropertyScreen extends StatefulWidget {
  final PropertyModel? property;

  const AddPropertyScreen({super.key, this.property});

  @override
  AddPropertyScreenState createState() => AddPropertyScreenState();
}

class AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _purchasePriceController = TextEditingController(); // ✅ سعر الشراء/التكلفة
  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _propertyImageService = PropertyImageService();
  final _propertyLocationService = PropertyLocationService();

  late LatLng _currentPosition;
  late PropertyType _selectedPropertyType;
  late OfferType _selectedOfferType;
  List<String> _images = []; // مسارات الملفات المحلية أو URLs
  List<File> _imageFiles = []; // الملفات المحلية فقط
  bool _hasGarage = false;
  bool _hasGarden = false;
  bool _hasPool = false;
  bool _hasSecurity = false;
  bool _isLoading = false;
  String? _selectedKitchenType;
  String? _selectedFinishingType;
  String? _selectedView;
  int _selectedFloor = 0;
  bool _hasElevator = false;
  bool _hasAC = false;
  bool _hasCentralAC = false;
  bool _hasInternetService = false;
  bool _has360View = false;
  String? _panoramaUrl;
  String? _virtualTourUrl;
  

  // ✅ تفاصيل الغرف والمساحات (جديد)
  final _bedroomsController = TextEditingController();
  final _masterBedroomsController = TextEditingController();
  final _livingRoomsController = TextEditingController();
  final _majlisController = TextEditingController();
  final _menMajlisController = TextEditingController();
  final _womenMajlisController = TextEditingController();
  final _diningRoomsController = TextEditingController();
  final _kitchensController = TextEditingController();
  final _masterBathroomsController = TextEditingController();
  final _guestBathroomsController = TextEditingController();
  final _serviceBathroomsController = TextEditingController();
  final _storageRoomsController = TextEditingController();
  final _maidRoomsController = TextEditingController();
  final _driverRoomsController = TextEditingController();
  final _laundryRoomsController = TextEditingController();
  final _totalBuiltAreaController = TextEditingController();
  final _landAreaController = TextEditingController();
  final _gardenAreaController = TextEditingController();
  final _yardAreaController = TextEditingController();
  
  // ✅ تفاصيل مهمة للعقارات في المملكة (جديد)
  bool _hasApartments = false;
  bool _hasInternalStairs = false;
  bool _hasExternalStairs = false;
  String? _selectedPropertyDirection;
  String? _selectedStreetWidth;
  final _livingRoomsCountController = TextEditingController();
  final _majlisCountController = TextEditingController();
  
  // ✅ تفاصيل الإيجار (جديد)
  final _monthlyRentController = TextEditingController();
  final _yearlyRentController = TextEditingController(); // ✅ إيجار سنوي
  bool _includesUtilities = false;
  String? _selectedMinimumRentPeriod;
  RentalType? _selectedRentalType;
  
  // ✅ حساب الربح
  final _profitPercentageController = TextEditingController(); // ✅ النسبة المئوية
  final _expectedProfitController = TextEditingController(); // ✅ متوقع الربح

  final List<String> _kitchenTypes = ['مطبخ مفتوح', 'مطبخ أمريكي', 'مطبخ عادي'];
  final List<String> _finishingTypes = ['سوبر لوكس', 'لوكس', 'نصف تشطيب', 'على العظم'];
  final List<String> _viewTypes = ['إطلالة على البحر', 'إطلالة على الحديقة', 'إطلالة على المدينة', 'إطلالة على الشارع'];
  final List<String> _propertyDirections = ['شمالي', 'جنوبي', 'شرقي', 'غربي', 'شمالي شرقي', 'شمالي غربي', 'جنوبي شرقي', 'جنوبي غربي'];
  final List<String> _streetWidths = ['أقل من 10 متر', '10-15 متر', '15-20 متر', '20-30 متر', 'أكثر من 30 متر'];

  @override
  void initState() {
    super.initState();
    _currentPosition = const LatLng(24.7136, 46.6753); // الرياض (افتراضي)
    _selectedPropertyType = PropertyType.apartment;
    _selectedOfferType = OfferType.sale;

    if (widget.property != null) {
      _loadPropertyData();
    } else {
      // الحصول على الموقع الحالي تلقائياً عند إضافة عقار جديد
      _getCurrentLocation();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthState>();
      final t = auth.user?.type ?? auth.userType;
      if (!ListingVerticalGuard.mayPublishProperties(
        t,
        isAdmin: auth.isAdmin,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ListingVerticalGuard.denialMessageForPropertyListing(t),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    });
  }

  void _loadPropertyData() {
    final property = widget.property!;
    _titleController.text = property.title;
    _descriptionController.text = property.description;
    _priceController.text = property.price.toString();
    _purchasePriceController.text = property.purchasePrice?.toString() ?? '';
    _roomsController.text = property.rooms.toString();
    _bathroomsController.text = property.bathrooms.toString();
    _areaController.text = property.area.toString();
    _addressController.text = property.address;
    _currentPosition = property.location;
    _selectedPropertyType = property.type;
    _selectedOfferType = property.offerType;
    
    // ✅ تحميل تفاصيل الغرف والمساحات
    if (property.roomDetails != null) {
      final roomDetails = property.roomDetails!;
      _bedroomsController.text = roomDetails.bedrooms.toString();
      _masterBedroomsController.text = roomDetails.masterBedrooms.toString();
      _livingRoomsController.text = roomDetails.livingRooms.toString();
      _majlisController.text = roomDetails.majlis.toString();
      _menMajlisController.text = roomDetails.menMajlis.toString();
      _womenMajlisController.text = roomDetails.womenMajlis.toString();
      _diningRoomsController.text = roomDetails.diningRooms.toString();
      _kitchensController.text = roomDetails.kitchens.toString();
      _masterBathroomsController.text = roomDetails.masterBathrooms.toString();
      _guestBathroomsController.text = roomDetails.guestBathrooms.toString();
      _serviceBathroomsController.text = roomDetails.serviceBathrooms.toString();
      _storageRoomsController.text = roomDetails.storageRooms.toString();
      _maidRoomsController.text = roomDetails.maidRooms.toString();
      _driverRoomsController.text = roomDetails.driverRooms.toString();
      _laundryRoomsController.text = roomDetails.laundryRooms.toString();
      _totalBuiltAreaController.text = roomDetails.totalBuiltArea.toString();
      _landAreaController.text = roomDetails.landArea.toString();
      _gardenAreaController.text = roomDetails.gardenArea.toString();
      _yardAreaController.text = roomDetails.yardArea.toString();
    }
    
    // ✅ تحميل التفاصيل المهمة
    _hasApartments = property.hasApartments;
    _hasInternalStairs = property.hasInternalStairs;
    _hasExternalStairs = property.hasExternalStairs;
    _selectedPropertyDirection = property.propertyDirection;
    _selectedStreetWidth = property.streetWidth;
    if (property.livingRoomsCount != null) {
      _livingRoomsCountController.text = property.livingRoomsCount.toString();
    }
    if (property.majlisCount != null) {
      _majlisCountController.text = property.majlisCount.toString();
    }
    
    // ✅ تحميل تفاصيل الإيجار
    if (property.monthlyRent != null) {
      _monthlyRentController.text = property.monthlyRent.toString();
    }
    _includesUtilities = property.includesUtilities ?? false;
    if (property.minimumRentPeriod != null) {
      // تحويل عدد الأشهر إلى نص (1 شهر، 3 أشهر، إلخ)
      final months = property.minimumRentPeriod!;
      if (months == 1) {
        _selectedMinimumRentPeriod = '1 شهر';
      } else if (months == 3) {
        _selectedMinimumRentPeriod = '3 أشهر';
      } else if (months == 6) {
        _selectedMinimumRentPeriod = '6 أشهر';
      } else if (months == 12) {
        _selectedMinimumRentPeriod = '12 شهر';
      } else if (months == 24) {
        _selectedMinimumRentPeriod = '24 شهر';
      }
    }
    // ملاحظة: RentalType غير موجود في PropertyModel حالياً، سيتم إضافته لاحقاً
    
    // تحميل الصور (URLs من Firestore)
    _images = List.from(property.images);
    _imageFiles.clear(); // لا توجد ملفات محلية عند التعديل
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _purchasePriceController.dispose();
    _yearlyRentController.dispose();
    _profitPercentageController.dispose();
    _expectedProfitController.dispose();
    _areaController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _addressController.dispose();
    _bedroomsController.dispose();
    _masterBedroomsController.dispose();
    _livingRoomsController.dispose();
    _majlisController.dispose();
    _menMajlisController.dispose();
    _womenMajlisController.dispose();
    _diningRoomsController.dispose();
    _kitchensController.dispose();
    _masterBathroomsController.dispose();
    _guestBathroomsController.dispose();
    _serviceBathroomsController.dispose();
    _storageRoomsController.dispose();
    _maidRoomsController.dispose();
    _driverRoomsController.dispose();
    _laundryRoomsController.dispose();
    _totalBuiltAreaController.dispose();
    _landAreaController.dispose();
    _gardenAreaController.dispose();
    _yardAreaController.dispose();
    _livingRoomsCountController.dispose();
    _majlisCountController.dispose();
    _monthlyRentController.dispose();
    // ✅ تم إضافة dispose في السطر 219-221
    _yearlyRentController.dispose();
    _profitPercentageController.dispose();
    _expectedProfitController.dispose();
    super.dispose();
  }

  /// ✅ حساب الربح من سعر الشراء والنسبة المئوية
  void _calculateProfit() {
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0;
    final salePrice = double.tryParse(_priceController.text) ?? 0;
    
    if (purchasePrice > 0 && salePrice > 0) {
      // حساب الربح
      final profit = salePrice - purchasePrice;
      _expectedProfitController.text = profit.toStringAsFixed(0);
      
      // حساب النسبة المئوية
      final percentage = (profit / purchasePrice) * 100;
      _profitPercentageController.text = percentage.toStringAsFixed(1);
    } else if (purchasePrice > 0 && salePrice == 0) {
      // إذا كان هناك سعر شراء فقط، احسب من النسبة المئوية
      _calculateProfitFromPercentage();
    }
  }

  /// ✅ حساب الربح من النسبة المئوية
  void _calculateProfitFromPercentage() {
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0;
    final percentage = double.tryParse(_profitPercentageController.text) ?? 0;
    
    if (purchasePrice > 0 && percentage > 0) {
      // حساب الربح من النسبة المئوية
      final profit = purchasePrice * (percentage / 100);
      _expectedProfitController.text = profit.toStringAsFixed(0);
      
      // حساب سعر البيع
      final salePrice = purchasePrice + profit;
      if (_priceController.text.isEmpty || _priceController.text == '0') {
        _priceController.text = salePrice.toStringAsFixed(0);
        setState(() {});
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // الحصول على الموقع الحالي
      final location = await _propertyLocationService.getCurrentLocation();
      
      // الحصول على العنوان من الإحداثيات
      final address = await _propertyLocationService.getAddressFromLocation(location);
      
      if (!mounted) return;
      
          setState(() {
            _currentPosition = location;
            _addressController.text = address;
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديد موقعك الحالي بنجاح'),
              backgroundColor: AppColors.success,
            ),
    );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحديد الموقع: $e'),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: AppColors.white,
            onPressed: _getCurrentLocation,
          ),
        ),
      );
    }
  }

  /// ✅ حساب عدد الحقول المكتملة
  int _getCompletedFieldsCount() {
    int count = 0;
    
    // الحقول الأساسية
    if (_titleController.text.isNotEmpty) count++;
    if (_descriptionController.text.isNotEmpty) count++;
    if (_priceController.text.isNotEmpty) count++;
    if (_areaController.text.isNotEmpty) count++;
    if (_roomsController.text.isNotEmpty) count++;
    if (_bathroomsController.text.isNotEmpty) count++;
    if (_addressController.text.isNotEmpty) count++;
    if (_images.isNotEmpty) count++;
    
    // تفاصيل الغرف (اختيارية)
    if (_bedroomsController.text.isNotEmpty ||
        _livingRoomsController.text.isNotEmpty ||
        _majlisController.text.isNotEmpty) {
      count++;
    }
    
    // التفاصيل المهمة (اختيارية)
    if (_selectedPropertyDirection != null || _selectedStreetWidth != null) count++;
    
    return count;
  }
  
  /// ✅ حساب إجمالي الحقول
  int _getTotalFieldsCount() {
    return 8; // الحقول الأساسية المطلوبة
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          widget.property == null ? 'إضافة عقار' : 'تعديل العقار',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Progress Indicator (تحسين UX)
              PropertyProgressIndicator(
                completedFields: _getCompletedFieldsCount(),
                totalFields: _getTotalFieldsCount(),
              ),
              const SizedBox(height: 16),
              PropertyImagePicker(
                images: _images,
                imageFiles: _imageFiles,
                onImagesChanged: (images) {
                  setState(() {
                    _images = images;
                  });
                },
                onImageFilesChanged: (files) {
                  setState(() {
                    _imageFiles = files;
                  });
                },
                imagePicker: _imagePicker,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: getPropertyInputDecoration(
                  'عنوان العقار',
                  hint: 'مثال: فيلا مودرن للبيع في حي النرجس',
                  prefixIcon: Icons.title,
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (_) => setState(() {}), // لتحديث progress indicator
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال عنوان العقار';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: getPropertyInputDecoration(
                  'وصف العقار',
                  hint: 'وصف تفصيلي للعقار والمميزات...',
                  prefixIcon: Icons.description,
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 3,
                onChanged: (_) => setState(() {}), // لتحديث progress indicator
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال وصف العقار';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              PropertyTypeSelector(
                selectedType: _selectedPropertyType,
                onTypeChanged: (type) {
                  setState(() {
                    _selectedPropertyType = type;
                  });
                },
              ),
              const SizedBox(height: 16),
              OfferTypeSelector(
                selectedType: _selectedOfferType,
                onTypeChanged: (type) {
                  setState(() {
                    _selectedOfferType = type;
                  });
                },
              ),
              // ✅ عرض تفاصيل الإيجار فقط عند اختيار "إيجار"
              if (_selectedOfferType == OfferType.rent) ...[
                const SizedBox(height: 16),
                PropertyRentalDetailsSection(
                  monthlyRentController: _monthlyRentController,
                  yearlyRentController: _yearlyRentController, // ✅ إيجار سنوي
                  includesUtilities: _includesUtilities,
                  selectedMinimumRentPeriod: _selectedMinimumRentPeriod,
                  selectedRentalType: _selectedRentalType,
                  onIncludesUtilitiesChanged: (value) {
                    setState(() {
                      _includesUtilities = value;
                    });
                  },
                  onMinimumRentPeriodChanged: (value) {
                    setState(() {
                      _selectedMinimumRentPeriod = value;
                    });
                  },
                  onRentalTypeChanged: (value) {
                    setState(() {
                      _selectedRentalType = value;
                    });
                  },
                  onChanged: () => setState(() {}),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: getPropertyInputDecoration(
                        'السعر',
                        hint: 'مثال: 500000',
                        prefixIcon: Icons.attach_money,
                      ).copyWith(
                        suffixText: 'ريال',
                        suffixStyle: const TextStyle(color: AppColors.textPrimary),
                      ),
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _calculateProfit();
                        setState(() {});
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال السعر';
                        }
                        if (double.tryParse(value) == null) {
                          return 'الرجاء إدخال رقم صحيح';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ✅ قسم حساب الربح
              Container(
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.2),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_up, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'حساب الربح',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ✅ سعر الشراء/التكلفة
                    TextFormField(
                      controller: _purchasePriceController,
                      decoration: getPropertyInputDecoration(
                        'سعر الشراء/التكلفة (اختياري)',
                        hint: 'مثال: 2000000',
                        prefixIcon: Icons.account_balance_wallet,
                      ).copyWith(
                        suffixText: 'ريال',
                        suffixStyle: const TextStyle(color: AppColors.textPrimary),
                        helperText: 'سعر الشراء (للعقارات الجاهزة)\nأو التكلفة (للعقارات المنفذة) - يستخدم لحساب الربح',
                        helperMaxLines: 2,
                        helperStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _calculateProfit();
                        setState(() {});
                      },
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'الرجاء إدخال رقم صحيح';
                          }
                          final purchasePrice = double.parse(value);
                          final salePrice = double.tryParse(_priceController.text) ?? 0;
                          if (purchasePrice > salePrice && salePrice > 0) {
                            return 'سعر الشراء يجب أن يكون أقل من سعر البيع';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // ✅ النسبة المئوية ومتوقع الربح
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _profitPercentageController,
                            decoration: getPropertyInputDecoration(
                              'النسبة المئوية (%)',
                              hint: 'مثال: 25',
                              prefixIcon: Icons.percent,
                            ).copyWith(
                              suffixText: '%',
                              suffixStyle: const TextStyle(color: AppColors.textPrimary),
                            ),
                            style: const TextStyle(color: AppColors.textPrimary),
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              _calculateProfitFromPercentage();
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _expectedProfitController,
                            decoration: getPropertyInputDecoration(
                              'متوقع الربح',
                              hint: 'مثال: 500000',
                              prefixIcon: Icons.attach_money,
                            ).copyWith(
                              suffixText: 'ريال',
                              suffixStyle: const TextStyle(color: AppColors.textPrimary),
                              helperText: 'يُحسب تلقائياً',
                              helperStyle: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            style: const TextStyle(color: AppColors.textPrimary),
                            keyboardType: TextInputType.number,
                            readOnly: true, // ✅ للقراءة فقط - يُحسب تلقائياً
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'أدخل سعر الشراء والنسبة المئوية لحساب الربح تلقائياً',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _areaController,
                      decoration: getPropertyInputDecoration(
                        'المساحة',
                        hint: 'مثال: 500',
                        prefixIcon: Icons.square_foot,
                      ).copyWith(
                        suffixText: 'م²',
                        suffixStyle: const TextStyle(color: AppColors.textPrimary),
                      ),
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {}); // لتحديث progress indicator
                        // ✅ حساب تلقائي للمساحة المبنية المقترحة
                        if (value.isNotEmpty) {
                          final area = double.tryParse(value);
                          if (area != null && _totalBuiltAreaController.text.isEmpty) {
                            // اقتراح: المساحة المبنية = 80% من مساحة الأرض
                            final suggestedBuiltArea = (area * 0.8).toStringAsFixed(0);
                            _totalBuiltAreaController.text = suggestedBuiltArea;
                          }
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال المساحة';
                        }
                        if (double.tryParse(value) == null) {
                          return 'الرجاء إدخال رقم صحيح';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _roomsController,
                      decoration: getPropertyInputDecoration('عدد الغرف'),
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال عدد الغرف';
                        }
                        if (int.tryParse(value) == null) {
                          return 'الرجاء إدخال رقم صحيح';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _bathroomsController,
                      decoration: getPropertyInputDecoration('عدد الحمامات'),
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال عدد الحمامات';
                        }
                        if (int.tryParse(value) == null) {
                          return 'الرجاء إدخال رقم صحيح';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ✅ تفاصيل الغرف والمساحات (جديد)
              PropertyRoomDetailsSection(
                bedroomsController: _bedroomsController,
                masterBedroomsController: _masterBedroomsController,
                livingRoomsController: _livingRoomsController,
                majlisController: _majlisController,
                menMajlisController: _menMajlisController,
                womenMajlisController: _womenMajlisController,
                diningRoomsController: _diningRoomsController,
                kitchensController: _kitchensController,
                masterBathroomsController: _masterBathroomsController,
                guestBathroomsController: _guestBathroomsController,
                serviceBathroomsController: _serviceBathroomsController,
                storageRoomsController: _storageRoomsController,
                maidRoomsController: _maidRoomsController,
                driverRoomsController: _driverRoomsController,
                laundryRoomsController: _laundryRoomsController,
                totalBuiltAreaController: _totalBuiltAreaController,
                landAreaController: _landAreaController,
                gardenAreaController: _gardenAreaController,
                yardAreaController: _yardAreaController,
                roomsController: _roomsController,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 24),
              // ✅ تفاصيل مهمة للعقارات في المملكة (جديد)
              PropertySaudiDetailsSection(
                hasApartments: _hasApartments,
                hasInternalStairs: _hasInternalStairs,
                hasExternalStairs: _hasExternalStairs,
                selectedPropertyDirection: _selectedPropertyDirection,
                selectedStreetWidth: _selectedStreetWidth,
                livingRoomsCountController: _livingRoomsCountController,
                majlisCountController: _majlisCountController,
                propertyDirections: _propertyDirections,
                streetWidths: _streetWidths,
                onHasApartmentsChanged: (value) => setState(() => _hasApartments = value),
                onHasInternalStairsChanged: (value) => setState(() => _hasInternalStairs = value),
                onHasExternalStairsChanged: (value) => setState(() => _hasExternalStairs = value),
                onPropertyDirectionChanged: (value) => setState(() => _selectedPropertyDirection = value),
                onStreetWidthChanged: (value) => setState(() => _selectedStreetWidth = value),
              ),
              const SizedBox(height: 24),
              PropertyFeaturesSection(
                selectedKitchenType: _selectedKitchenType,
                selectedFinishingType: _selectedFinishingType,
                selectedView: _selectedView,
                selectedFloor: _selectedFloor,
                hasElevator: _hasElevator,
                hasAC: _hasAC,
                hasCentralAC: _hasCentralAC,
                hasInternetService: _hasInternetService,
                hasGarage: _hasGarage,
                hasGarden: _hasGarden,
                hasPool: _hasPool,
                hasSecurity: _hasSecurity,
                kitchenTypes: _kitchenTypes,
                finishingTypes: _finishingTypes,
                viewTypes: _viewTypes,
                onKitchenTypeChanged: (value) => setState(() => _selectedKitchenType = value),
                onFinishingTypeChanged: (value) => setState(() => _selectedFinishingType = value),
                onViewChanged: (value) => setState(() => _selectedView = value),
                onFloorChanged: (value) => setState(() => _selectedFloor = value),
                onHasElevatorChanged: (value) => setState(() => _hasElevator = value),
                onHasACChanged: (value) => setState(() => _hasAC = value),
                onHasCentralACChanged: (value) => setState(() => _hasCentralAC = value),
                onHasInternetServiceChanged: (value) => setState(() => _hasInternetService = value),
                onHasGarageChanged: (value) => setState(() => _hasGarage = value),
                onHasGardenChanged: (value) => setState(() => _hasGarden = value),
                onHasPoolChanged: (value) => setState(() => _hasPool = value),
                onHasSecurityChanged: (value) => setState(() => _hasSecurity = value),
              ),
              const SizedBox(height: 24),
              PropertyLocationPicker(
                currentPosition: _currentPosition,
                onLocationChanged: (position) {
                  setState(() {
                    _currentPosition = position;
                  });
                },
                locationService: _propertyLocationService,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: getPropertyInputDecoration('العنوان التفصيلي'),
                style: const TextStyle(color: AppColors.textPrimary),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال العنوان';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Property360ViewSection(
                has360View: _has360View,
                virtualTourUrl: _virtualTourUrl,
                imagePicker: _imagePicker,
                onHas360ViewChanged: (value) {
                  setState(() {
                    _has360View = value;
                    if (!value) {
                      _panoramaUrl = null;
                    }
                  });
                },
                onVirtualTourUrlChanged: (value) {
                  setState(() {
                    _virtualTourUrl = value;
                  });
                },
                onPanoramaUrlChanged: (value) {
                  setState(() {
                    _panoramaUrl = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.transparent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      widget.property == null ? 'إضافة العقار' : 'حفظ التعديلات',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_images.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إضافة صورة واحدة على الأقل')),
        );
        return;
      }

      // ✅ حفظ BuildContext قبل async operations
      final authState = context.read<AuthState>();
      final propertyProvider = context.read<PropertyProvider>();
      final mapState = context.read<MapState>();

      setState(() {
        _isLoading = true;
      });

      try {
        // ✅ رفع الصور إلى Cloudflare Images فقط (NOT Firebase Storage)
        List<String> imageUrls = [];
        
        // إذا كانت هناك صور موجودة مسبقاً (URLs من Cloudflare Images)، أضفها
        for (final image in _images) {
          if (image.startsWith('http')) {
            imageUrls.add(image);
          }
        }
        
        // رفع الصور الجديدة (الملفات المحلية)
        if (_imageFiles.isNotEmpty) {
          // إنشاء معرف مؤقت للعقار (سيتم استبداله بالمعرف الفعلي بعد الحفظ)
          final tempPropertyId = widget.property?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
          
          // ✅ رفع جميع الصور الجديدة مع تتبع الأخطاء
          int successCount = 0;
          int failCount = 0;
          String? lastError;
          
          for (int i = 0; i < _imageFiles.length; i++) {
            try {
              final url = await _propertyImageService.uploadImage(_imageFiles[i], tempPropertyId);
              imageUrls.add(url);
              successCount++;
              debugPrint('✅ تم رفع الصورة ${i + 1}/${_imageFiles.length} بنجاح');
            } catch (e) {
              failCount++;
              lastError = e.toString();
              debugPrint('❌ فشل رفع الصورة ${i + 1}/${_imageFiles.length}: $e');
              // نتابع رفع باقي الصور حتى لو فشلت واحدة
            }
          }
          
          // ✅ تسجيل ملخص عملية الرفع
          debugPrint('📊 ملخص رفع الصور: نجح $successCount، فشل $failCount من ${_imageFiles.length}');
          
          if (successCount == 0 && failCount > 0) {
            // ✅ فشل رفع كل الصور - إيقاف العملية
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل رفع جميع الصور. الخطأ: ${lastError ?? "غير معروف"}'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 5),
              ),
            );
            return;
          }
          
          if (failCount > 0) {
            // ✅ تحذير: بعض الصور فشلت لكن البعض نجح
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم رفع $successCount صورة بنجاح، فشل $failCount صورة'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        
        // ✅ التحقق الإلزامي: يجب أن يكون هناك صورة واحدة على الأقل بعد الرفع
        if (imageUrls.isEmpty) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل رفع الصور. يرجى المحاولة مرة أخرى.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        final features = <String, bool>{
          'موقف سيارات': _hasGarage,
          'حديقة': _hasGarden,
          'مسبح': _hasPool,
          'حراسة أمنية': _hasSecurity,
          'مصعد': _hasElevator,
          'تكييف': _hasAC,
          'تكييف مركزي': _hasCentralAC,
          'خدمة إنترنت': _hasInternetService,
        };

        final amenities = <String>[
          if (_selectedKitchenType != null) _selectedKitchenType!,
          if (_selectedFinishingType != null) _selectedFinishingType!,
          if (_selectedView != null) _selectedView!,
        ];

        // ✅ تحويل فترة الإيجار من نص إلى عدد (بالأشهر)
        int? minimumRentPeriodMonths;
        if (_selectedMinimumRentPeriod != null) {
          if (_selectedMinimumRentPeriod == '1 شهر') {
            minimumRentPeriodMonths = 1;
          } else if (_selectedMinimumRentPeriod == '3 أشهر') {
            minimumRentPeriodMonths = 3;
          } else if (_selectedMinimumRentPeriod == '6 أشهر') {
            minimumRentPeriodMonths = 6;
          } else if (_selectedMinimumRentPeriod == '12 شهر') {
            minimumRentPeriodMonths = 12;
          } else if (_selectedMinimumRentPeriod == '24 شهر') {
            minimumRentPeriodMonths = 24;
          }
        }

        // ✅ بناء تفاصيل الغرف والمساحات
        PropertyRoomDetails? roomDetails;
        if (_bedroomsController.text.isNotEmpty ||
            _livingRoomsController.text.isNotEmpty ||
            _majlisController.text.isNotEmpty ||
            _diningRoomsController.text.isNotEmpty ||
            _kitchensController.text.isNotEmpty) {
          roomDetails = PropertyRoomDetails(
            bedrooms: int.tryParse(_bedroomsController.text) ?? 0,
            masterBedrooms: int.tryParse(_masterBedroomsController.text) ?? 0,
            livingRooms: int.tryParse(_livingRoomsController.text) ?? 0,
            majlis: int.tryParse(_majlisController.text) ?? 0,
            menMajlis: int.tryParse(_menMajlisController.text) ?? 0,
            womenMajlis: int.tryParse(_womenMajlisController.text) ?? 0,
            diningRooms: int.tryParse(_diningRoomsController.text) ?? 0,
            kitchens: int.tryParse(_kitchensController.text) ?? 0,
            bathrooms: int.parse(_bathroomsController.text),
            masterBathrooms: int.tryParse(_masterBathroomsController.text) ?? 0,
            guestBathrooms: int.tryParse(_guestBathroomsController.text) ?? 0,
            serviceBathrooms: int.tryParse(_serviceBathroomsController.text) ?? 0,
            storageRooms: int.tryParse(_storageRoomsController.text) ?? 0,
            maidRooms: int.tryParse(_maidRoomsController.text) ?? 0,
            driverRooms: int.tryParse(_driverRoomsController.text) ?? 0,
            laundryRooms: int.tryParse(_laundryRoomsController.text) ?? 0,
            totalBuiltArea: double.tryParse(_totalBuiltAreaController.text) ?? 0.0,
            landArea: double.tryParse(_landAreaController.text) ?? 0.0,
            gardenArea: double.tryParse(_gardenAreaController.text) ?? 0.0,
            yardArea: double.tryParse(_yardAreaController.text) ?? 0.0,
          );
        }

        final property = PropertyModel(
          id: widget.property?.id ?? '',
          title: _titleController.text,
          description: _descriptionController.text,
          price: double.parse(_priceController.text),
          purchasePrice: _purchasePriceController.text.isNotEmpty
              ? double.tryParse(_purchasePriceController.text)
              : null,
          images: imageUrls, // ✅ استخدام URLs من Cloudflare Images (NOT Firebase Storage)
          address: _addressController.text,
          location: _currentPosition,
          ownerId: authState.user?.id ?? '',
          offerType: _selectedOfferType,
          status: PropertyStatus.available,
          type: _selectedPropertyType,
          rooms: int.parse(_roomsController.text),
          bathrooms: int.parse(_bathroomsController.text),
          area: double.parse(_areaController.text),
          roomDetails: roomDetails,
          hasApartments: _hasApartments,
          hasInternalStairs: _hasInternalStairs,
          hasExternalStairs: _hasExternalStairs,
          propertyDirection: _selectedPropertyDirection,
          streetWidth: _selectedStreetWidth,
          livingRoomsCount: int.tryParse(_livingRoomsCountController.text),
          majlisCount: int.tryParse(_majlisCountController.text),
          features: features,
          amenities: amenities,
          floors: _selectedFloor,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contactPhone: authState.user?.extraData?['phoneNumber'] ?? '+966500000000',
          has360View: _has360View,
          panoramaUrl: _panoramaUrl,
          virtualTourUrl: _virtualTourUrl,
          // ✅ بيانات الإيجار (تظهر فقط عند اختيار "إيجار")
          monthlyRent: _selectedOfferType == OfferType.rent && _monthlyRentController.text.isNotEmpty
              ? double.tryParse(_monthlyRentController.text)
              : null,
          includesUtilities: _selectedOfferType == OfferType.rent ? _includesUtilities : null,
          minimumRentPeriod: _selectedOfferType == OfferType.rent ? minimumRentPeriodMonths : null,
        );

        PropertyModel? savedProperty;
        
        if (widget.property == null) {
          // ✅ إضافة العقار والحصول على ID الصحيح من Firestore مباشرة
          savedProperty = await propertyProvider.addProperty(property);
          
          // ✅ إعادة تحميل القائمة من Firestore لضمان ظهور العقار الجديد
          await propertyProvider.loadProperties();
          
          if (!mounted) return;
          
          // ✅ تحديث MapState أيضاً
          mapState.updateProperties(propertyProvider.properties);
          
          // ✅ تسجيل ID العقار للتأكد
          debugPrint('✅✅✅ Property added with ID: ${savedProperty.id}');
          debugPrint('✅✅✅ Property title: ${savedProperty.title}');
          debugPrint('✅✅✅ Property images count: ${savedProperty.images.length}');
        } else {
          savedProperty = await propertyProvider.updateProperty(property);
          // ✅ إعادة تحميل القائمة بعد التحديث
          await propertyProvider.loadProperties();
          
          if (!mounted) return;
          
          // ✅ تحديث MapState أيضاً
          mapState.updateProperties(propertyProvider.properties);
          
          // ✅ تسجيل ID العقار المحدث
          debugPrint('✅✅✅ Property updated with ID: ${savedProperty.id}');
        }

        if (!mounted) return;
        
        // ✅ إرجاع العقار المحفوظ مع ID الصحيح
        Navigator.pop(context, savedProperty);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
} 