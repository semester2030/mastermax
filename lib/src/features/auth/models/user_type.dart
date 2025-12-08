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

  static UserType fromString(String value) {
    return UserType.values.firstWhere(
      (type) => type.toString().split('.').last == value,
      orElse: () => UserType.individual,
    );
  }
} 