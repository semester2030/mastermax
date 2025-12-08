import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/logger.dart';

/// خدمة إدارة مميزات العقارات
class PropertyFeaturesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// المميزات الداخلية للعقار
  static const Map<String, String> interiorFeatures = {
    'central_ac': 'تكييف مركزي',
    'furnished': 'مفروش',
    'kitchen_appliances': 'أجهزة مطبخ',
    'storage_room': 'غرفة تخزين',
    'maid_room': 'غرفة خادمة',
    'laundry_room': 'غرفة غسيل',
    'intercom': 'انتركم',
  };

  /// المميزات الخارجية للعقار
  static const Map<String, String> exteriorFeatures = {
    'parking': 'موقف سيارات',
    'garden': 'حديقة',
    'pool': 'مسبح',
    'balcony': 'شرفة',
    'roof_top': 'سطح خاص',
    'driver_room': 'غرفة سائق',
    'separate_entrance': 'مدخل منفصل',
  };

  /// مميزات الأمن والخدمات
  static const Map<String, String> securityAndServices = {
    'security': 'أمن',
    'elevator': 'مصعد',
    'gym': 'صالة رياضية',
    'internet': 'خدمة إنترنت',
    'satellite': 'قنوات فضائية',
    'maintenance': 'خدمة صيانة',
  };

  /// المرافق القريبة
  static const Map<String, String> nearbyAmenities = {
    'school': 'مدرسة',
    'hospital': 'مستشفى',
    'mall': 'مركز تسوق',
    'mosque': 'مسجد',
    'park': 'حديقة عامة',
    'restaurant': 'مطاعم',
    'pharmacy': 'صيدلية',
    'supermarket': 'سوبرماركت',
    'public_transport': 'مواصلات عامة',
    'beach': 'شاطئ',
  };

  /// الحصول على جميع المميزات المتاحة
  static Map<String, String> get allFeatures => {
    ...interiorFeatures,
    ...exteriorFeatures,
    ...securityAndServices,
  };

  /// إضافة أو تحديث مميزات العقار
  Future<void> updatePropertyFeatures(
    String propertyId,
    Map<String, bool> features,
    List<String> amenities,
  ) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'features': features,
        'amenities': amenities,
      });
    } catch (e) {
      logError('Error updating property features', e);
      rethrow;
    }
  }

  /// الحصول على مميزات العقار
  Future<Map<String, dynamic>> getPropertyFeatures(String propertyId) async {
    try {
      final doc = await _firestore.collection('properties').doc(propertyId).get();
      if (!doc.exists) {
        throw Exception('العقار غير موجود');
      }
      return {
        'features': Map<String, bool>.from(doc.data()?['features'] ?? {}),
        'amenities': List<String>.from(doc.data()?['amenities'] ?? []),
      };
    } catch (e) {
      logError('Error getting property features', e);
      rethrow;
    }
  }

  /// إضافة ميزة جديدة للعقار
  Future<void> addFeature(
    String propertyId,
    String featureKey,
    bool value,
  ) async {
    try {
      if (!allFeatures.containsKey(featureKey)) {
        throw Exception('الميزة غير موجودة في قائمة المميزات المتاحة');
      }
      await _firestore.collection('properties').doc(propertyId).update({
        'features.$featureKey': value,
      });
    } catch (e) {
      logError('Error adding feature', e);
      rethrow;
    }
  }

  /// حذف ميزة من العقار
  Future<void> removeFeature(String propertyId, String featureKey) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'features.$featureKey': FieldValue.delete(),
      });
    } catch (e) {
      logError('Error removing feature', e);
      rethrow;
    }
  }

  /// إضافة مرفق قريب
  Future<void> addAmenity(String propertyId, String amenity) async {
    try {
      if (!nearbyAmenities.containsKey(amenity)) {
        throw Exception('المرفق غير موجود في قائمة المرافق المتاحة');
      }
      await _firestore.collection('properties').doc(propertyId).update({
        'amenities': FieldValue.arrayUnion([amenity]),
      });
    } catch (e) {
      logError('Error adding amenity', e);
      rethrow;
    }
  }

  /// حذف مرفق قريب
  Future<void> removeAmenity(String propertyId, String amenity) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'amenities': FieldValue.arrayRemove([amenity]),
      });
    } catch (e) {
      logError('Error removing amenity', e);
      rethrow;
    }
  }

  /// البحث عن العقارات حسب المميزات
  Future<List<String>> searchPropertiesByFeatures(
    Map<String, bool> requiredFeatures,
    List<String> requiredAmenities,
  ) async {
    try {
      Query query = _firestore.collection('properties');

      // التحقق من صحة المميزات المطلوبة
      for (final feature in requiredFeatures.keys) {
        if (!allFeatures.containsKey(feature)) {
          throw Exception('ميزة غير صالحة: $feature');
        }
      }

      // التحقق من صحة المرافق المطلوبة
      for (final amenity in requiredAmenities) {
        if (!nearbyAmenities.containsKey(amenity)) {
          throw Exception('مرفق غير صالح: $amenity');
        }
      }

      // إضافة شروط البحث للمميزات
      for (final feature in requiredFeatures.entries) {
        query = query.where('features.${feature.key}', isEqualTo: feature.value);
      }

      // إضافة شروط البحث للمرافق
      if (requiredAmenities.isNotEmpty) {
        query = query.where('amenities', arrayContainsAny: requiredAmenities);
      }

      final QuerySnapshot result = await query.get();
      return result.docs.map((doc) => doc.id).toList();
    } catch (e) {
      logError('Error searching properties by features', e);
      rethrow;
    }
  }

  /// الحصول على إحصائيات المميزات
  Future<Map<String, dynamic>> getFeaturesStatistics() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('properties').get();
      final Map<String, int> featureStats = {};
      final Map<String, int> amenityStats = {};

      for (final doc in snapshot.docs) {
        final Map<String, bool> features =
            Map<String, bool>.from(doc.get('features') ?? {});
        final List<String> amenities =
            List<String>.from(doc.get('amenities') ?? []);

        // إحصائيات المميزات
        for (final feature in features.entries) {
          if (feature.value) {
            featureStats[feature.key] = (featureStats[feature.key] ?? 0) + 1;
          }
        }

        // إحصائيات المرافق
        for (final amenity in amenities) {
          amenityStats[amenity] = (amenityStats[amenity] ?? 0) + 1;
        }
      }

      return {
        'features': featureStats,
        'amenities': amenityStats,
      };
    } catch (e) {
      logError('Error getting features statistics', e);
      rethrow;
    }
  }
} 