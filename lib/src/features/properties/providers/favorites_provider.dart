import 'package:flutter/foundation.dart';
import '../models/property_model.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteIds = {};
  final Map<String, PropertyModel> _favorites = {};

  bool isFavorite(String id) => _favoriteIds.contains(id);
  List<PropertyModel> get favorites => _favorites.values.toList();

  void toggleFavorite(PropertyModel property) {
    if (isFavorite(property.id)) {
      removeFromFavorites(property.id);
    } else {
      addToFavorites(property);
    }
  }

  void addToFavorites(PropertyModel property) {
    _favoriteIds.add(property.id);
    _favorites[property.id] = property;
    notifyListeners();
  }

  void removeFromFavorites(String id) {
    _favoriteIds.remove(id);
    _favorites.remove(id);
    notifyListeners();
  }

  void clearFavorites() {
    _favoriteIds.clear();
    _favorites.clear();
    notifyListeners();
  }
} 