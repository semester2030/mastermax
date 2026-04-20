import 'package:flutter/foundation.dart';
import '../models/property_model.dart';
import '../services/property_service.dart';

/// مزود إدارة العقارات
class PropertyProvider extends ChangeNotifier {
  final PropertyService _propertyService;
  List<PropertyModel> _properties = [];
  PropertyModel? _selectedProperty;
  bool _isLoading = false;
  String? _error;

  PropertyProvider(this._propertyService);

  /// ✅ Service للوصول من خارج الـ Provider
  PropertyService get service => _propertyService;

  /// قائمة العقارات
  List<PropertyModel> get properties => _properties;

  /// العقار المحدد
  PropertyModel? get selectedProperty => _selectedProperty;

  /// حالة التحميل
  bool get isLoading => _isLoading;

  /// رسالة الخطأ
  String? get error => _error;

  /// تحميل العقارات
  Future<void> loadProperties({String? ownerId}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final loadedProperties = await _propertyService.getProperties(ownerId: ownerId);
      _properties = loadedProperties;
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading properties: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// إلب عقار بواسطة المعرف
  Future<void> fetchPropertyById(String propertyId) async {
    try {
      // ✅ التحقق من أن propertyId غير فارغ
      if (propertyId.isEmpty) {
        debugPrint('❌ fetchPropertyById: Property ID is empty');
        _error = 'معرف العقار غير صحيح';
        _isLoading = false;
        _selectedProperty = null;
        notifyListeners();
        return;
      }
      
      debugPrint('🔍 fetchPropertyById: Loading property with ID: $propertyId');
      
      _isLoading = true;
      _error = null;
      _selectedProperty = null;
      notifyListeners();

      // ✅ جلب العقار من Firestore
      _selectedProperty = await _propertyService.getPropertyById(propertyId);
      
      if (_selectedProperty == null) {
        debugPrint('❌ fetchPropertyById: Property not found in Firestore: $propertyId');
        _error = 'لم يتم العثور على العقار';
      } else {
        debugPrint('✅ fetchPropertyById: Property loaded successfully');
        debugPrint('✅ Property ID: ${_selectedProperty!.id}');
        debugPrint('✅ Property title: ${_selectedProperty!.title}');
        debugPrint('✅ Property images count: ${_selectedProperty!.images.length}');
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ fetchPropertyById: Error loading property $propertyId: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      _error = 'حدث خطأ أثناء تحميل العقار: $e';
      _isLoading = false;
      _selectedProperty = null;
      notifyListeners();
    }
  }

  /// اختيار عقار
  void selectProperty(PropertyModel? property) {
    _selectedProperty = property;
    notifyListeners();
  }

  /// إضافة عقار جديد
  /// 
  /// ✅ يُرجع العقار المُضاف مع ID الصحيح من Firestore
  Future<PropertyModel> addProperty(PropertyModel property) async {
    try {
      // ✅ إضافة العقار إلى Firestore والحصول على ID الصحيح
      final newProperty = await _propertyService.addProperty(property);
      
      // ✅ إضافة العقار إلى القائمة المحلية
      _properties.add(newProperty);
      notifyListeners();
      
      // ✅ إرجاع العقار مع ID الصحيح
      return newProperty;
    } catch (e) {
      debugPrint('Error adding property: $e');
      rethrow;
    }
  }

  /// تحديث عقار
  Future<PropertyModel> updateProperty(PropertyModel property) async {
    try {
      final updatedProperty = await _propertyService.updateProperty(property);
      final index = _properties.indexWhere((p) => p.id == property.id);
      if (index != -1) {
        _properties[index] = updatedProperty;
        notifyListeners();
      }
      return updatedProperty;
    } catch (e) {
      debugPrint('Error updating property: $e');
      rethrow;
    }
  }

  /// حذف عقار
  Future<void> deleteProperty(String propertyId) async {
    try {
      final success = await _propertyService.deleteProperty(propertyId);
      if (success) {
        _properties.removeWhere((p) => p.id == propertyId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting property: $e');
      rethrow;
    }
  }

  /// البحث عن عقارات
  Future<void> searchProperties(String query) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _properties = await _propertyService.searchProperties(query);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'حدث خطأ أثناء البحث عن العقارات';
      _isLoading = false;
      notifyListeners();
    }
  }

  // دالة للحصول على عقار بواسطة المعرف
  Future<PropertyModel?> getProperty(String id) async {
    try {
      // في الحالة الحقيقية، قم بالبحث في قاعدة البيانات
      return _properties.firstWhere((property) => property.id == id);
    } catch (e) {
      return null;
    }
  }

  // دالة للبحث عن العقارات
  Future<List<PropertyModel>> searchPropertiesByQuery(String query) async {
    try {
      final normalizedQuery = query.toLowerCase();
      return _properties.where((property) {
        return property.title.toLowerCase().contains(normalizedQuery) ||
               property.address.toLowerCase().contains(normalizedQuery) ||
               property.type.toString().toLowerCase().contains(normalizedQuery);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  PropertyModel? getPropertyById(String propertyId) {
    try {
      return _properties.firstWhere((p) => p.id == propertyId);
    } catch (e) {
      return null;
    }
  }
} 