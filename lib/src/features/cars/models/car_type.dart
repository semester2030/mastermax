enum CarType {
  sedan,      // سيدان
  suv,        // دفع رباعي
  luxury,     // فاخرة
  sports,     // رياضية
  commercial, // تجارية
  other       // أخرى
}

extension CarTypeExtension on CarType {
  String get arabicName {
    switch (this) {
      case CarType.sedan:
        return 'سيدان';
      case CarType.suv:
        return 'دفع رباعي';
      case CarType.luxury:
        return 'فاخرة';
      case CarType.sports:
        return 'رياضية';
      case CarType.commercial:
        return 'تجارية';
      case CarType.other:
        return 'أخرى';
    }
  }
} 