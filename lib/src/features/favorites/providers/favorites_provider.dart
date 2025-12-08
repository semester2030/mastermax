import 'package:flutter/material.dart';
import '../../../features/properties/models/property_model.dart';
import '../../../features/cars/models/car_model.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteIds = {};
  final Map<String, dynamic> _favorites = {};
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool isFavorite(String id) => _favoriteIds.contains(id);
  List<dynamic> get favorites => _favorites.values.toList();

  Future<void> loadFavorites(String? userId) async {
    if (userId == null) return;
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // في المستقبل، يمكننا تحميل المفضلة من قاعدة البيانات
      await Future.delayed(const Duration(milliseconds: 500));
      
    } catch (e) {
      _error = 'حدث خطأ أثناء تحميل المفضلة';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addToFavorites(dynamic item) {
    try {
      if (item is PropertyModel || item is CarModel) {
        final id = item.id as String;
        _favoriteIds.add(id);
        _favorites[id] = item;
        notifyListeners();
      }
    } catch (e) {
      _error = 'حدث خطأ أثناء إضافة العنصر للمفضلة';
      notifyListeners();
    }
  }

  void removeFromFavorites(String id) {
    try {
      _favoriteIds.remove(id);
      _favorites.remove(id);
      notifyListeners();
    } catch (e) {
      _error = 'حدث خطأ أثناء إزالة العنصر من المفضلة';
      notifyListeners();
    }
  }

  void clearFavorites() {
    try {
      _favoriteIds.clear();
      _favorites.clear();
      notifyListeners();
    } catch (e) {
      _error = 'حدث خطأ أثناء مسح المفضلة';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  List<PropertyModel> get propertyFavorites => 
    _favorites.values.whereType<PropertyModel>().toList();

  List<CarModel> get carFavorites => 
    _favorites.values.whereType<CarModel>().toList();
} 