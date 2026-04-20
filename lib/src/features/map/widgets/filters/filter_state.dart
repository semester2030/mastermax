import 'package:flutter/material.dart';
import '../../../properties/models/property_model.dart';

/// إدارة حالة فلاتر الخريطة
/// يحتوي على جميع المتغيرات والبيانات المطلوبة للفلترة
class FilterState {
  // === نطاقات القيم ===
  RangeValues priceRange = const RangeValues(0, 10000000);
  RangeValues areaRange = const RangeValues(0, 1000);
  RangeValues yearRange = const RangeValues(2000, 2024);
  RangeValues kmRange = const RangeValues(0, 300000);
  RangeValues roomsRange = const RangeValues(1, 10);
  RangeValues bathroomsRange = const RangeValues(1, 5);
  RangeValues livingRoomsRange = const RangeValues(0, 5);
  RangeValues majlisRange = const RangeValues(0, 3);
  RangeValues kitchensRange = const RangeValues(1, 3);

  // === فلاتر العقارات ===
  String selectedPropertyType = 'شقة';
  OfferType? selectedOfferType;
  String? selectedCity;
  String? selectedDistrict;
  String? selectedDirection;
  String? selectedAge;
  String? propertyAge;
  String? propertyDirection;
  String? streetWidth;
  final List<String> selectedAmenities = [];
  
  // === فلاتر السيارات ===
  String? selectedCarMake;
  String? selectedCarType;
  String? selectedFuelType;
  String? selectedTransmission;
  String? selectedCarColor;
  String? selectedCarCondition;
  String? selectedEngine;
  String? selectedInteriorColor;
  String? selectedDriveType;
  String? selectedBodyStyle;
  String? selectedSeatsCount;
  String? selectedCylinders;
  String? selectedTrimLevel;
  final List<String> selectedCarFeatures = [];

  // === فلاتر مشتركة ===
  bool hasParking = false;
  bool hasPool = false;
  bool isNew = false;
  bool has360View = false;
  bool hasVirtualTour = false;
  bool hasInteriorView = false;

  // === فلاتر العقارات المتقدمة ===
  bool hasGarden = false;
  bool hasRoofTop = false;
  bool hasGym = false;
  bool hasStorage = false;
  bool hasSecurity = false;
  bool hasIntercom = false;
  bool hasBasement = false;
  bool hasDriverRoom = false;
  bool hasMaidRoom = false;
  bool hasSwimmingPool = false;
  bool isFirstOwner = false;
  bool isRegisteredInNetwork = false;
  bool isMortgageAvailable = false;
  bool isNegotiable = false;
  bool hasElevator = false;
  bool hasCarEntrance = false;
  bool hasYard = false;
  bool hasTent = false;
  bool hasGuardRoom = false;
  bool hasWellWater = false;
  bool hasAirConditioners = false;
  bool hasKitchenCabinets = false;
  bool hasCentralAC = false;
  bool hasGardenLighting = false;
  bool hasElectricGate = false;
  bool hasFireAlarm = false;
  bool hasSecurityCameras = false;

  // === فلاتر السيارات المتقدمة ===
  bool isWarranty = false;
  bool isInsurance = false;
  bool isImported = false;
  bool hasServiceHistory = false;
  bool hasAccidentHistory = false;
  bool isGccSpecs = false;
  bool hasCustomNumber = false;
  bool isAgencyMaintained = false;
  bool isUnderWarranty = false;
  bool isExportable = false;
  bool isFirstOwnerCar = false;
  bool isNegotiableCar = false;
  bool hasPanoramicRoof = false;
  bool hasAdaptiveCruiseControl = false;
  bool hasBlindSpotMonitoring = false;
  bool hasLaneAssist = false;
  bool has360Camera = false;
  bool hasHeadUpDisplay = false;
  bool hasWirelessCharging = false;
  bool hasRemoteStart = false;
  bool hasVentilatedSeats = false;
  bool hasMemorySeats = false;
  bool hasMassageSeats = false;
  bool hasThirdRow = false;

  /// إعادة تعيين جميع الفلاتر إلى القيم الافتراضية
  void reset({required bool isRealEstate}) {
    priceRange = const RangeValues(0, 10000000);
    areaRange = const RangeValues(0, 1000);
    yearRange = const RangeValues(2000, 2024);
    kmRange = const RangeValues(0, 300000);
    roomsRange = const RangeValues(1, 10);
    bathroomsRange = const RangeValues(1, 5);
    livingRoomsRange = const RangeValues(0, 5);
    majlisRange = const RangeValues(0, 3);
    kitchensRange = const RangeValues(1, 3);

    selectedPropertyType = 'شقة';
    selectedOfferType = null;
    selectedCity = null;
    selectedDistrict = null;
    selectedDirection = null;
    selectedAge = null;
    propertyAge = null;
    propertyDirection = null;
    streetWidth = null;
    selectedAmenities.clear();

    selectedCarMake = null;
    selectedCarType = null;
    selectedFuelType = null;
    selectedTransmission = null;
    selectedCarColor = null;
    selectedCarCondition = null;
    selectedEngine = null;
    selectedInteriorColor = null;
    selectedDriveType = null;
    selectedBodyStyle = null;
    selectedSeatsCount = null;
    selectedCylinders = null;
    selectedTrimLevel = null;
    selectedCarFeatures.clear();

    hasParking = false;
    hasPool = false;
    isNew = false;
    has360View = false;
    hasVirtualTour = false;
    hasInteriorView = false;

    if (isRealEstate) {
      hasGarden = false;
      hasRoofTop = false;
      hasGym = false;
      hasStorage = false;
      hasSecurity = false;
      hasIntercom = false;
      hasBasement = false;
      hasDriverRoom = false;
      hasMaidRoom = false;
      hasSwimmingPool = false;
      isFirstOwner = false;
      isRegisteredInNetwork = false;
      isMortgageAvailable = false;
      isNegotiable = false;
      hasElevator = false;
      hasCarEntrance = false;
      hasYard = false;
      hasTent = false;
      hasGuardRoom = false;
      hasWellWater = false;
      hasAirConditioners = false;
      hasKitchenCabinets = false;
      hasCentralAC = false;
      hasGardenLighting = false;
      hasElectricGate = false;
      hasFireAlarm = false;
      hasSecurityCameras = false;
    } else {
      isWarranty = false;
      isInsurance = false;
      isImported = false;
      hasServiceHistory = false;
      hasAccidentHistory = false;
      isGccSpecs = false;
      hasCustomNumber = false;
      isAgencyMaintained = false;
      isUnderWarranty = false;
      isExportable = false;
      isFirstOwnerCar = false;
      isNegotiableCar = false;
      hasPanoramicRoof = false;
      hasAdaptiveCruiseControl = false;
      hasBlindSpotMonitoring = false;
      hasLaneAssist = false;
      has360Camera = false;
      hasHeadUpDisplay = false;
      hasWirelessCharging = false;
      hasRemoteStart = false;
      hasVentilatedSeats = false;
      hasMemorySeats = false;
      hasMassageSeats = false;
      hasThirdRow = false;
    }
  }

  /// حساب عدد الفلاتر النشطة
  int getSelectedCount({required bool isRealEstate}) {
    if (isRealEstate) {
      return selectedAmenities.length +
          (hasParking ? 1 : 0) +
          (hasPool ? 1 : 0) +
          (isNew ? 1 : 0) +
          (selectedCity != null ? 1 : 0) +
          (selectedDistrict != null ? 1 : 0) +
          (selectedOfferType != null ? 1 : 0);
    } else {
      return selectedCarFeatures.length +
          (isWarranty ? 1 : 0) +
          (isInsurance ? 1 : 0) +
          (isImported ? 1 : 0) +
          (selectedCarMake != null ? 1 : 0) +
          (selectedCarType != null ? 1 : 0) +
          (selectedFuelType != null ? 1 : 0) +
          (selectedTransmission != null ? 1 : 0) +
          (selectedCity != null ? 1 : 0) +
          (selectedCarColor != null ? 1 : 0) +
          (selectedCarCondition != null ? 1 : 0);
    }
  }

  /// تحويل الفلاتر إلى Map للإرجاع
  Map<String, dynamic> toMap({required bool isRealEstate}) {
    if (isRealEstate) {
      return {
        'propertyType': selectedPropertyType,
        'offerType': selectedOfferType,
        'priceRange': priceRange,
        'areaRange': areaRange,
        'roomsRange': roomsRange,
        'bathroomsRange': bathroomsRange,
        'city': selectedCity,
        'amenities': selectedAmenities,
        'hasParking': hasParking,
        'hasPool': hasPool,
        'isNew': isNew,
        'direction': selectedDirection,
        'age': selectedAge,
        'hasGarden': hasGarden,
        'hasRoofTop': hasRoofTop,
        'hasGym': hasGym,
        'hasStorage': hasStorage,
        'hasSecurity': hasSecurity,
        'hasIntercom': hasIntercom,
        'hasBasement': hasBasement,
        'hasDriverRoom': hasDriverRoom,
        'hasMaidRoom': hasMaidRoom,
        'hasSwimmingPool': hasSwimmingPool,
        'isFirstOwner': isFirstOwner,
        'isRegisteredInNetwork': isRegisteredInNetwork,
        'isMortgageAvailable': isMortgageAvailable,
        'isNegotiable': isNegotiable,
        'has360View': has360View,
        'hasVirtualTour': hasVirtualTour,
        'hasInteriorView': hasInteriorView,
        'hasElevator': hasElevator,
      };
    } else {
      return {
        'carMake': selectedCarMake,
        'carType': selectedCarType,
        'yearRange': yearRange,
        'priceRange': priceRange,
        'kmRange': kmRange,
        'fuelType': selectedFuelType,
        'transmission': selectedTransmission,
        'city': selectedCity,
        'features': selectedCarFeatures,
        'isWarranty': isWarranty,
        'isInsurance': isInsurance,
        'isImported': isImported,
        'engineSize': selectedEngine,
        'interiorColor': selectedInteriorColor,
        'driveType': selectedDriveType,
        'hasServiceHistory': hasServiceHistory,
        'hasAccidentHistory': hasAccidentHistory,
        'isGccSpecs': isGccSpecs,
        'hasCustomNumber': hasCustomNumber,
        'isAgencyMaintained': isAgencyMaintained,
        'isUnderWarranty': isUnderWarranty,
        'isExportable': isExportable,
        'isFirstOwnerCar': isFirstOwnerCar,
        'isNegotiableCar': isNegotiableCar,
        'bodyStyle': selectedBodyStyle,
        'seatsCount': selectedSeatsCount,
        'cylinders': selectedCylinders,
        'trimLevel': selectedTrimLevel,
        'hasPanoramicRoof': hasPanoramicRoof,
        'hasAdaptiveCruiseControl': hasAdaptiveCruiseControl,
        'hasBlindSpotMonitoring': hasBlindSpotMonitoring,
        'hasLaneAssist': hasLaneAssist,
        'has360Camera': has360Camera,
        'hasHeadUpDisplay': hasHeadUpDisplay,
        'hasWirelessCharging': hasWirelessCharging,
        'hasRemoteStart': hasRemoteStart,
        'hasVentilatedSeats': hasVentilatedSeats,
        'hasMemorySeats': hasMemorySeats,
        'hasMassageSeats': hasMassageSeats,
        'hasThirdRow': hasThirdRow,
        'has360View': has360View,
        'hasVirtualTour': hasVirtualTour,
        'hasInteriorView': hasInteriorView,
        'carColor': selectedCarColor,
        'carCondition': selectedCarCondition,
      };
    }
  }
}
