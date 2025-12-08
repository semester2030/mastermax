import 'package:flutter/foundation.dart';
import '../models/property_model.dart';
import '../models/property_type.dart';
import '../services/property_service.dart';

/// حالة إدارة العقارات
class PropertyState extends ChangeNotifier {
  final PropertyService _propertyService;
  
  List<PropertyModel> _properties = [];
  PropertyType? _selectedType;
  double? _minPrice;
  double? _maxPrice;
  int? _minRooms;
  String? _location;
  bool? _isAvailable;
  bool _isLoading = false;
  String? _error;

  PropertyState(this._propertyService);

  /// قائمة العقارات
  List<PropertyModel> get properties => _properties;
  
  /// نوع العقار المحدد
  PropertyType? get selectedType => _selectedType;
  
  /// السعر الأدنى
  double? get minPrice => _minPrice;
  
  /// السعر الأعلى
  double? get maxPrice => _maxPrice;
  
  /// الحد الأدنى لعدد الغرف
  int? get minRooms => _minRooms;
  
  /// الموقع
  String? get location => _location;
  
  /// متاح للبيع/الإيجار
  bool? get isAvailable => _isAvailable;
  
  /// حالة التحميل
  bool get isLoading => _isLoading;
  
  /// رسالة الخطأ
  String? get error => _error;

  /// تحديث المرشحات
  void updateFilters({
    PropertyType? type,
    double? minPrice,
    double? maxPrice,
    int? minRooms,
    String? location,
    bool? isAvailable,
  }) {
    _selectedType = type;
    _minPrice = minPrice;
    _maxPrice = maxPrice;
    _minRooms = minRooms;
    _location = location;
    _isAvailable = isAvailable;
    notifyListeners();
    
    // تحديث القائمة مع المرشحات الجديدة
    loadProperties();
  }

  /// تحميل العقارات
  Future<void> loadProperties() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _properties = await _propertyService.getProperties(
        type: _selectedType,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        minRooms: _minRooms,
        location: _location,
        isAvailable: _isAvailable,
      );
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'حدث خطأ أثناء تحميل العقارات';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// إعادة تعيين المرشحات
  void resetFilters() {
    _selectedType = null;
    _minPrice = null;
    _maxPrice = null;
    _minRooms = null;
    _location = null;
    _isAvailable = null;
    notifyListeners();
    
    // تحميل القائمة بدون مرشحات
    loadProperties();
  }
} 