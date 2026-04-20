enum UserType {
  individual,
  realEstateCompany,
  carDealer,
  realEstateAgent,
  carTrader;

  String get arabicName {
    switch (this) {
      case UserType.individual:
        return 'فرد';
      case UserType.realEstateCompany:
        return 'شركة عقارية';
      case UserType.carDealer:
        return 'معرض سيارات';
      case UserType.realEstateAgent:
        return 'وسيط عقاري';
      case UserType.carTrader:
        return 'تاجر سيارات';
    }
  }

  bool get requiresCommercialRegistry {
    return this == UserType.realEstateCompany || this == UserType.carDealer;
  }

  bool get requiresLicense {
    return this == UserType.realEstateAgent || this == UserType.carTrader;
  }

  /// ✅ التحقق من الحاجة لرفع وثائق التحقق
  /// 
  /// الأنواع التي تحتاج تحقق:
  /// - realEstateCompany: شركة عقارية
  /// - carDealer: معرض سيارات
  /// - realEstateAgent: وسيط عقاري
  /// 
  /// الأنواع التي لا تحتاج تحقق:
  /// - carTrader: تاجر سيارات
  /// - individual: فرد
  bool get requiresVerification {
    return this == UserType.realEstateCompany ||
           this == UserType.carDealer ||
           this == UserType.realEstateAgent;
  }

  /// ✅ الحصول على الوثائق المطلوبة لكل نوع حساب
  String get requiredDocuments {
    switch (this) {
      case UserType.realEstateCompany:
        return 'السجل التجاري + الرخصة العقارية + جميع الوثائق المطلوبة';
      case UserType.carDealer:
        return 'السجل التجاري + جميع الوثائق المطلوبة';
      case UserType.realEstateAgent:
        return 'الرخصة/الترخيص + جميع الوثائق المطلوبة';
      default:
        return '';
    }
  }

  /// يقبل `carDealer` أو `UserType.carDealer` (كما يُخزَّن من [Enum.toString]).
  static UserType fromString(String value) {
    if (value.isEmpty) return UserType.individual;
    final key = value.contains('.') ? value.split('.').last : value;
    return UserType.values.firstWhere(
      (type) => type.name == key,
      orElse: () => UserType.individual,
    );
  }
} 