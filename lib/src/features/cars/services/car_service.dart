import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/geo/saudi_region_parser.dart';
import '../models/car_model.dart';
import 'package:flutter/foundation.dart';

class CarService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'cars';

  Future<List<CarModel>> getCars() async {
    try {
      debugPrint('Starting to fetch cars from Firestore');
      // بدون Source.server على الويب حتى يُسمح للـ cache بالعمل وتقليل زمن الظهور.
      final snapshot = await _db.collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      debugPrint(
        '${kIsWeb ? 'Web' : 'Mobile'}: Fetched ${snapshot.docs.length} cars',
      );

      if (snapshot.docs.isEmpty) {
        debugPrint('No cars found in Firestore');
        return [];
      }

      final cars = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return CarModel.fromMap(data, doc.id);
      }).toList();

      cars.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint('Successfully processed ${cars.length} cars');
      return cars;
    } catch (e) {
      debugPrint('Error getting cars: $e');
      _logError('Error getting cars', e);
      throw 'فشل في تحميل السيارات. الرجاء المحاولة مرة أخرى';
    }
  }

  Future<CarModel?> getCar(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return CarModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> addCar(CarModel car) async {
    try {
      _validateCarData(car);
      
      final carData = {
        ...car.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };
      SaudiRegionParser.applyToFirestoreMap(carData, (carData['address'] ?? '').toString());

      final docRef = await _db.collection(_collection).add(carData);
      return docRef.id;
    } catch (e) {
      _logError('Error adding car', e);
      throw 'فشل في إضافة السيارة. الرجاء المحاولة مرة أخرى';
    }
  }

  void _validateCarData(CarModel car) {
    if (car.title.isEmpty) {
      throw 'عنوان السيارة مطلوب';
    }
    if (car.price <= 0) {
      throw 'سعر السيارة يجب أن يكون أكبر من صفر';
    }
    // يمكن إضافة المزيد من التحققات حسب الحاجة
  }

  Future<void> updateCar(CarModel car) async {
    try {
      final carData = car.toMap();
      SaudiRegionParser.applyToFirestoreMap(carData, (carData['address'] ?? '').toString());
      await _db.collection(_collection).doc(car.id).update(carData);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCar(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<CarModel>> watchCars() {
    return _db.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CarModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<CarModel?> watchCar(String id) {
    return _db.collection(_collection).doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CarModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<CarModel?> getCarById(String id) async {
    try {
      final doc = await _db.collection('cars').doc(id).get();
      if (!doc.exists) return null;
      return CarModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      _logError('Error getting car by ID', e);
      return null;
    }
  }

  void _logError(String message, dynamic error) {
    if (kDebugMode) {
      print('$message: $error');
    }
  }
} 