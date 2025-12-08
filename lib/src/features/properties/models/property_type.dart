enum PropertyType {
  apartment,
  villa,
  land,
  commercial,
  other;

  String toArabic() {
    switch (this) {
      case PropertyType.apartment:
        return 'شقة';
      case PropertyType.villa:
        return 'فيلا';
      case PropertyType.land:
        return 'أرض';
      case PropertyType.commercial:
        return 'تجاري';
      case PropertyType.other:
        return 'أخرى';
    }
  }

  static PropertyType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'apartment':
        return PropertyType.apartment;
      case 'villa':
        return PropertyType.villa;
      case 'land':
        return PropertyType.land;
      case 'commercial':
        return PropertyType.commercial;
      default:
        return PropertyType.other;
    }
  }
} 