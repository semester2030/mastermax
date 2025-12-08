import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/logger.dart';

/// خدمة إدارة أسعار وعروض العقارات
class PropertyPricingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// تحديث سعر العقار
  Future<void> updatePropertyPrice(
    String propertyId,
    double price, {
    bool isNegotiable = false,
  }) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'price': price,
        'isNegotiable': isNegotiable,
        'priceHistory': FieldValue.arrayUnion([
          {
            'price': price,
            'date': FieldValue.serverTimestamp(),
          }
        ]),
      });
    } catch (e) {
      logError('Error updating property price', e);
      rethrow;
    }
  }

  /// إضافة عرض خاص
  Future<String> addSpecialOffer({
    required String propertyId,
    required double originalPrice,
    required double discountedPrice,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
  }) async {
    try {
      final offer = await _firestore.collection('special_offers').add({
        'propertyId': propertyId,
        'originalPrice': originalPrice,
        'discountedPrice': discountedPrice,
        'startDate': startDate,
        'endDate': endDate,
        'description': description,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return offer.id;
    } catch (e) {
      logError('Error adding special offer', e);
      rethrow;
    }
  }

  /// تحديث عرض خاص
  Future<void> updateSpecialOffer({
    required String offerId,
    double? discountedPrice,
    DateTime? endDate,
    String? description,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (discountedPrice != null) updates['discountedPrice'] = discountedPrice;
      if (endDate != null) updates['endDate'] = endDate;
      if (description != null) updates['description'] = description;
      if (isActive != null) updates['isActive'] = isActive;

      await _firestore.collection('special_offers').doc(offerId).update(updates);
    } catch (e) {
      logError('Error updating special offer', e);
      rethrow;
    }
  }

  /// الحصول على العروض النشطة لعقار معين
  Future<List<DocumentSnapshot>> getActiveOffers(String propertyId) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('special_offers')
          .where('propertyId', isEqualTo: propertyId)
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: DateTime.now())
          .get();
      return result.docs;
    } catch (e) {
      logError('Error getting active offers', e);
      rethrow;
    }
  }

  /// إضافة خطة سداد
  Future<String> addPaymentPlan({
    required String propertyId,
    required double totalPrice,
    required int numberOfInstallments,
    required double downPayment,
    required double monthlyPayment,
    String? description,
  }) async {
    try {
      final plan = await _firestore.collection('payment_plans').add({
        'propertyId': propertyId,
        'totalPrice': totalPrice,
        'numberOfInstallments': numberOfInstallments,
        'downPayment': downPayment,
        'monthlyPayment': monthlyPayment,
        'description': description,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return plan.id;
    } catch (e) {
      logError('Error adding payment plan', e);
      rethrow;
    }
  }

  /// الحصول على خطط السداد المتاحة
  Future<List<DocumentSnapshot>> getPaymentPlans(String propertyId) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('payment_plans')
          .where('propertyId', isEqualTo: propertyId)
          .where('isActive', isEqualTo: true)
          .get();
      return result.docs;
    } catch (e) {
      logError('Error getting payment plans', e);
      rethrow;
    }
  }

  /// حساب السعر النهائي مع العروض
  Future<Map<String, dynamic>> calculateFinalPrice(String propertyId) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      final double originalPrice = propertyDoc.get('price');
      double finalPrice = originalPrice;
      String? appliedOfferId;
      double? discountPercentage;

      // البحث عن أفضل عرض متاح
      final activeOffers = await getActiveOffers(propertyId);
      if (activeOffers.isNotEmpty) {
        double bestDiscount = 0;
        for (final offer in activeOffers) {
          final double offerPrice = offer.get('discountedPrice');
          final double discount = originalPrice - offerPrice;
          if (discount > bestDiscount) {
            bestDiscount = discount;
            finalPrice = offerPrice;
            appliedOfferId = offer.id;
            discountPercentage = (discount / originalPrice) * 100;
          }
        }
      }

      return {
        'originalPrice': originalPrice,
        'finalPrice': finalPrice,
        'appliedOfferId': appliedOfferId,
        'discountPercentage': discountPercentage,
        'isNegotiable': propertyDoc.get('isNegotiable') ?? false,
      };
    } catch (e) {
      logError('Error calculating final price', e);
      rethrow;
    }
  }

  /// الحصول على تاريخ الأسعار
  Future<List<Map<String, dynamic>>> getPriceHistory(String propertyId) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      final List<dynamic> history = propertyDoc.get('priceHistory') ?? [];
      return List<Map<String, dynamic>>.from(history);
    } catch (e) {
      logError('Error getting price history', e);
      rethrow;
    }
  }

  /// مقارنة الأسعار مع العقارات المشابهة
  Future<Map<String, dynamic>> comparePrices(
    String propertyId,
    double radius, // بالكيلومتر
  ) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      final double propertyPrice = propertyDoc.get('price');
      final String propertyType = propertyDoc.get('type');
      final double propertyArea = propertyDoc.get('area');

      // البحث عن العقارات المشابهة في نفس المنطقة
      final QuerySnapshot similarProperties = await _firestore
          .collection('properties')
          .where('type', isEqualTo: propertyType)
          .where('area', isGreaterThan: propertyArea * 0.8)
          .where('area', isLessThan: propertyArea * 1.2)
          .get();

      double totalPrice = 0;
      int count = 0;
      double minPrice = double.infinity;
      double maxPrice = 0;
      final List<double> pricePerMeter = [];

      for (final doc in similarProperties.docs) {
        if (doc.id != propertyId) {
          final double price = doc.get('price');
          final double area = doc.get('area');
          
          totalPrice += price;
          count++;
          minPrice = price < minPrice ? price : minPrice;
          maxPrice = price > maxPrice ? price : maxPrice;
          pricePerMeter.add(price / area);
        }
      }

      return {
        'propertyPrice': propertyPrice,
        'averagePrice': count > 0 ? totalPrice / count : propertyPrice,
        'minPrice': count > 0 ? minPrice : propertyPrice,
        'maxPrice': count > 0 ? maxPrice : propertyPrice,
        'pricePerMeter': propertyPrice / propertyArea,
        'averagePricePerMeter': count > 0
            ? pricePerMeter.reduce((a, b) => a + b) / pricePerMeter.length
            : propertyPrice / propertyArea,
        'similarPropertiesCount': count,
      };
    } catch (e) {
      logError('Error comparing prices', e);
      rethrow;
    }
  }
} 