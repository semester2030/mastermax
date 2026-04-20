import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../features/properties/models/property_model.dart';
import '../../../features/cars/models/car_model.dart';
import '../../../features/spotlight/models/video_model.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteIds = {};
  final Map<String, dynamic> _favorites = {};
  bool _isLoading = false;
  String? _error;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

      // تحميل المفضلة من Firestore
      final favoritesSnapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .get();

      _favoriteIds.clear();
      _favorites.clear();

      for (var doc in favoritesSnapshot.docs) {
        try {
          final data = doc.data();
          final itemId = data['itemId'] as String?;
          final type = data['type'] as String?;
          
          if (itemId == null || type == null) {
            continue; // تخطي المستندات غير الصحيحة
          }
          
          _favoriteIds.add(itemId);
          
          // جلب بيانات العنصر حسب النوع
          if (type == 'property') {
            final propertyDoc = await _firestore
                .collection('properties')
                .doc(itemId)
                .get();
            if (propertyDoc.exists && propertyDoc.data() != null) {
              try {
                _favorites[itemId] = PropertyModel.fromJson({
                  'id': propertyDoc.id,
                  ...propertyDoc.data()!,
                });
              } catch (e) {
                debugPrint('[FavoritesProvider] خطأ في تحميل عقار: $e');
              }
            }
          } else if (type == 'car') {
            final carDoc = await _firestore
                .collection('cars')
                .doc(itemId)
                .get();
            if (carDoc.exists && carDoc.data() != null) {
              try {
                _favorites[itemId] = CarModel.fromJson({
                  'id': carDoc.id,
                  ...carDoc.data()!,
                });
              } catch (e) {
                debugPrint('[FavoritesProvider] خطأ في تحميل سيارة: $e');
              }
            }
          } else if (type == 'video') {
            final videoDoc = await _firestore
                .collection('videos')
                .doc(itemId)
                .get();
            if (videoDoc.exists && videoDoc.data() != null) {
              try {
                _favorites[itemId] = VideoModel.fromJson({
                  'id': videoDoc.id,
                  ...videoDoc.data()!,
                });
              } catch (e) {
                debugPrint('[FavoritesProvider] خطأ في تحميل فيديو: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('[FavoritesProvider] خطأ في معالجة مستند مفضلة: $e');
          continue; // تخطي المستندات التي تسبب خطأ
        }
      }
      
    } catch (e) {
      _error = 'حدث خطأ أثناء تحميل المفضلة: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToFavorites(dynamic item, String userId) async {
    try {
      String? itemId;
      String? type;
      
      if (item is PropertyModel) {
        itemId = item.id;
        type = 'property';
      } else if (item is CarModel) {
        itemId = item.id;
        type = 'car';
      } else if (item is VideoModel) {
        itemId = item.id;
        type = 'video';
      } else {
        throw Exception('نوع العنصر غير مدعوم');
      }

      if (itemId == null) return;

      // حفظ في Firestore
      await _firestore.collection('favorites').add({
        'userId': userId,
        'itemId': itemId,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // حفظ محلياً
      _favoriteIds.add(itemId);
      _favorites[itemId] = item;
      notifyListeners();
    } catch (e) {
      _error = 'حدث خطأ أثناء إضافة العنصر للمفضلة: $e';
      notifyListeners();
    }
  }

  Future<void> removeFromFavorites(String id, String userId) async {
    try {
      // حذف من Firestore
      final favoritesSnapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: id)
          .get();

      for (var doc in favoritesSnapshot.docs) {
        await doc.reference.delete();
      }

      // حذف محلياً
      _favoriteIds.remove(id);
      _favorites.remove(id);
      notifyListeners();
    } catch (e) {
      _error = 'حدث خطأ أثناء إزالة العنصر من المفضلة: $e';
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