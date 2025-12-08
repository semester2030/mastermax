
// تعريف أنواع العقارات
enum PropertyType {
  apartment,
  villa,
  land,
  commercial;

  String get arabicName {
    switch (this) {
      case PropertyType.apartment:
        return 'شقة';
      case PropertyType.villa:
        return 'فيلا';
      case PropertyType.land:
        return 'أرض';
      case PropertyType.commercial:
        return 'تجاري';
    }
  }
}

// تعريف طرق الدفع
enum PaymentMethod {
  cash,
  installment,
  mortgage;

  String get arabicName {
    switch (this) {
      case PaymentMethod.cash:
        return 'نقداً';
      case PaymentMethod.installment:
        return 'تقسيط';
      case PaymentMethod.mortgage:
        return 'رهن عقاري';
    }
  }
}

// تفاصيل العقار
class PropertyDetails {
  final String title;
  final PropertyType type;
  final String location;
  final double area;
  final int rooms;
  final int bathrooms;
  final bool isFurnished;
  final double purchasePrice;
  final double targetPrice;
  final int daysInMarket;

  PropertyDetails({
    required this.title,
    required this.type,
    required this.location,
    required this.area,
    required this.rooms,
    required this.bathrooms,
    required this.isFurnished,
    required this.purchasePrice,
    required this.targetPrice,
    required this.daysInMarket,
  });

  double get expectedProfit => targetPrice - purchasePrice;
}

// تفاصيل عملية البيع
class Sale {
  final PropertyDetails propertyDetails;
  final double amount;
  final PaymentMethod paymentMethod;
  final DateTime date;
  final int daysToSell;

  Sale({
    required this.propertyDetails,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    required this.daysToSell,
  });

  double get profit => amount - propertyDetails.purchasePrice;
} 