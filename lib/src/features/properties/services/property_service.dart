import '../models/property_model.dart';
import '../models/property_type.dart';
import '../../../core/geo/saudi_region_parser.dart';
import '../../../core/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// خدمة إدارة العقارات
class PropertyService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  PropertyService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // تم إزالة البيانات الافتراضية - البيانات تُجلب من Firestore فقط

  /// إضافة عقار جديد
  Future<PropertyModel> addProperty(PropertyModel property) async {
    try {
      // ✅ إزالة ID من البيانات قبل الحفظ (Firestore سينشئ ID تلقائياً)
      final propertyData = property.toJson();
      propertyData.remove('id'); // ✅ إزالة ID الفارغ
      SaudiRegionParser.applyToFirestoreMap(
        propertyData,
        (propertyData['address'] ?? '').toString(),
      );

      // إضافة العقار إلى Firestore
      final docRef = await _firestore.collection('properties').add(propertyData);
      
      // ✅ جلب العقار المضافة مع المعرف الجديد
      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('فشل في إنشاء العقار');
      }
      
      final docData = doc.data() as Map<String, dynamic>;
      // ✅ إزالة 'id' من docData إذا كان موجوداً (لضمان استخدام doc.id فقط)
      docData.remove('id');
      
      return PropertyModel.fromJson({
        'id': doc.id, // ✅ استخدام doc.id من Firestore (مضمون وغير فارغ)
        ...docData,
      });
    } catch (e) {
      logError('Error adding property', e);
      rethrow;
    }
  }

  /// تحديث بيانات عقار
  Future<PropertyModel> updateProperty(PropertyModel property) async {
    try {
      // ✅ التحقق من أن ID غير فارغ
      if (property.id.isEmpty) {
        throw Exception('معرف العقار غير صحيح');
      }
      
      // ✅ إزالة ID من البيانات قبل التحديث
      final propertyData = property.copyWith(updatedAt: DateTime.now()).toJson();
      propertyData.remove('id'); // ✅ إزالة ID (Firestore يستخدم doc.id)
      SaudiRegionParser.applyToFirestoreMap(
        propertyData,
        (propertyData['address'] ?? '').toString(),
      );

      // تحديث العقار في Firestore
      await _firestore.collection('properties').doc(property.id).update(propertyData);
      
      // ✅ جلب العقار المحدث
      final doc = await _firestore.collection('properties').doc(property.id).get();
      if (!doc.exists) {
        throw Exception('العقار غير موجود');
      }
      
      final docData = doc.data() as Map<String, dynamic>;
      // ✅ إزالة 'id' من docData إذا كان موجوداً (لضمان استخدام doc.id فقط)
      docData.remove('id');
      
      return PropertyModel.fromJson({
        'id': doc.id, // ✅ استخدام doc.id من Firestore (مضمون وغير فارغ)
        ...docData,
      });
    } catch (e) {
      logError('Error updating property', e);
      rethrow;
    }
  }

  /// حذف عقار
  Future<bool> deleteProperty(String propertyId) async {
    try {
      // حذف العقار من Firestore
      await _firestore.collection('properties').doc(propertyId).delete();
      return true;
    } catch (e) {
      logError('Error deleting property', e);
      return false;
    }
  }

  /// جلب عقار بواسطة المعرف
  Future<PropertyModel?> getPropertyById(String propertyId) async {
    try {
      // ✅ التحقق من أن propertyId غير فارغ
      if (propertyId.isEmpty) {
        logError('getPropertyById: Property ID is empty', Exception('Empty property ID'));
        return null;
      }
      
      logInfo('🔍 getPropertyById: Fetching property from Firestore: $propertyId');
      
      final doc = await _firestore.collection('properties').doc(propertyId).get();
      
      if (!doc.exists) {
        logError('getPropertyById: Property not found in Firestore', Exception('Document does not exist'));
        logInfo('❌ Property ID: $propertyId does not exist in Firestore');
        return null;
      }
      
      final data = doc.data();
      if (data == null) {
        logError('getPropertyById: Property data is null', Exception('Document data is null'));
        return null;
      }
      
      final property = PropertyModel.fromJson({
        'id': doc.id,
        ...data,
      });
      
      logInfo('✅ getPropertyById: Property loaded successfully');
      logInfo('✅ Property ID: ${property.id}');
      logInfo('✅ Property title: ${property.title}');
      logInfo('✅ Property images count: ${property.images.length}');
      
      return property;
    } catch (e, stackTrace) {
      logError('Error getting property', e, stackTrace);
      return null;
    }
  }

  /// جلب قائمة العقارات
  Future<List<PropertyModel>> getProperties({
    PropertyType? type,
    double? minPrice,
    double? maxPrice,
    int? minRooms,
    String? location,
    bool? isAvailable,
    String? ownerId, // إضافة ownerId لفلترة العقارات حسب المالك
  }) async {
    try {
      // جلب البيانات من Firestore
      Query query = _firestore.collection('properties');
      
      // فلترة حسب المالك إذا تم توفيره (للحسابات التجارية)
      if (ownerId != null && ownerId.isNotEmpty) {
        query = query.where('ownerId', isEqualTo: ownerId);
      }
      
      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        // لا توجد عقارات في Firestore - إرجاع قائمة فارغة
        return [];
      }
      
      var properties = snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          // ✅ التأكد من أن doc.id غير فارغ
          if (doc.id.isEmpty) {
            logError('getProperties: Document ID is empty', Exception('Empty document ID'));
            return null;
          }
          
          final property = PropertyModel.fromJson({
            'id': doc.id,
            ...data,
          });
          
          // ✅ التحقق النهائي من أن ID غير فارغ بعد parsing
          if (property.id.isEmpty) {
            logError('getProperties: Property ID is empty after parsing (doc.id: ${doc.id})', Exception('Empty property ID after parsing'));
            return null;
          }
          
          return property;
        } catch (e) {
          logError('getProperties: Error parsing property ${doc.id}', e);
          return null;
        }
      }).where((p) => p != null).cast<PropertyModel>().toList();
      
      // ✅ تسجيل عدد العقارات الصالحة
      if (properties.length != snapshot.docs.length) {
        logInfo('⚠️ Filtered out ${snapshot.docs.length - properties.length} properties with invalid IDs');
      }
      logInfo('✅ Loaded ${properties.length} valid properties from Firestore');

      // تطبيق الفلترة
      if (type != null) {
        properties = properties.where((p) => p.type == type).toList();
      }

      if (minPrice != null) {
        properties = properties.where((p) => p.price >= minPrice).toList();
      }

      if (maxPrice != null) {
        properties = properties.where((p) => p.price <= maxPrice).toList();
      }

      if (minRooms != null) {
        properties = properties.where((p) => p.rooms >= minRooms).toList();
      }

      if (location != null) {
        properties = properties
            .where((p) => p.address.toLowerCase().contains(location.toLowerCase()))
            .toList();
      }

      if (isAvailable != null) {
        properties = properties
            .where((p) => isAvailable ? p.status == PropertyStatus.available : p.status != PropertyStatus.available)
            .toList();
      }

      return properties;
    } catch (e) {
      logError('Error getting properties', e);
      return [];
    }
  }

  /// البحث عن عقارات
  Future<List<PropertyModel>> searchProperties(String query, {String? ownerId}) async {
    try {
      if (query.isEmpty) {
        // إذا كان البحث فارغاً، إرجاع جميع العقارات (أو عقارات المالك)
        return getProperties(ownerId: ownerId);
      }

      // البحث في Firestore
      Query firestoreQuery = _firestore.collection('properties');
      
      if (ownerId != null && ownerId.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('ownerId', isEqualTo: ownerId);
      }
      
      final snapshot = await firestoreQuery.get();
      
      if (snapshot.docs.isEmpty) {
        return [];
      }
      
      final searchQuery = query.toLowerCase();
      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return PropertyModel.fromJson({
              'id': doc.id,
              ...data,
            });
          })
          .where((property) {
            return property.title.toLowerCase().contains(searchQuery) ||
                property.description.toLowerCase().contains(searchQuery) ||
                property.address.toLowerCase().contains(searchQuery);
          })
          .toList();
    } catch (e) {
      logError('Error searching properties', e);
      return [];
    }
  }

  /// إضافة تقييم لعقار
  Future<bool> addPropertyReview(String propertyId, PropertyReview review) async {
    try {
      final property = await getPropertyById(propertyId);
      if (property == null) return false;

      final updatedProperty = property.copyWith(
        reviews: [...property.reviews, review],
      );
      await updateProperty(updatedProperty);
      return true;
    } catch (e) {
      logError('Error adding property review', e);
      return false;
    }
  }

  /// تحديث حالة العقار
  Future<bool> updatePropertyStatus(String propertyId, PropertyStatus status) async {
    try {
      final property = await getPropertyById(propertyId);
      if (property == null) return false;

      final updatedProperty = property.copyWith(status: status);
      await updateProperty(updatedProperty);
      return true;
    } catch (e) {
      logError('Error updating property status', e);
      return false;
    }
  }

  /// حساب متوسط التقييم
  double calculateAverageRating(List<PropertyReview> reviews) {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold(0.0, (sum, review) => sum + review.rating);
    return total / reviews.length;
  }

  // تم حذف getDummyProperties() - البيانات تُجلب من Firestore فقط
} 