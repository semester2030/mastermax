import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/logger.dart';
import '../models/property_model.dart';

/// خدمة إدارة حالة العقارات
class PropertyStatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// تحديث حالة العقار
  Future<void> updatePropertyStatus(
    String propertyId,
    PropertyStatus status, {
    String? reason,
  }) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'status': status.toString(),
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'statusReason': reason,
      });

      // تسجيل تغيير الحالة في السجل
      await _firestore
          .collection('properties')
          .doc(propertyId)
          .collection('status_history')
          .add({
        'status': status.toString(),
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Error updating property status', e);
      rethrow;
    }
  }

  /// تعليق العقار
  Future<void> suspendProperty(String propertyId, String reason) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'status': PropertyStatus.suspended.toString(),
        'isSuspended': true,
        'suspensionReason': reason,
        'suspendedAt': FieldValue.serverTimestamp(),
      });

      // إرسال إشعار للمالك
      await _firestore.collection('notifications').add({
        'userId': await getPropertyOwner(propertyId),
        'type': 'property_suspended',
        'propertyId': propertyId,
        'message': 'تم تعليق عقارك: $reason',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      logError('Error suspending property', e);
      rethrow;
    }
  }

  /// إلغاء تعليق العقار
  Future<void> unsuspendProperty(String propertyId) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      final String previousStatus = propertyDoc.get('previousStatus') ??
          PropertyStatus.available.toString();

      await _firestore.collection('properties').doc(propertyId).update({
        'status': previousStatus,
        'isSuspended': false,
        'suspensionReason': FieldValue.delete(),
        'suspendedAt': FieldValue.delete(),
        'unsuspendedAt': FieldValue.serverTimestamp(),
      });

      // إرسال إشعار للمالك
      await _firestore.collection('notifications').add({
        'userId': await getPropertyOwner(propertyId),
        'type': 'property_unsuspended',
        'propertyId': propertyId,
        'message': 'تم إلغاء تعليق عقارك',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      logError('Error unsuspending property', e);
      rethrow;
    }
  }

  /// تمييز العقار كمباع
  Future<void> markAsSold(
    String propertyId, {
    required double sellingPrice,
    String? buyerId,
    DateTime? soldDate,
  }) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'status': PropertyStatus.sold.toString(),
        'sellingPrice': sellingPrice,
        'buyerId': buyerId,
        'soldDate': soldDate ?? FieldValue.serverTimestamp(),
        'isAvailable': false,
      });

      // تسجيل عملية البيع
      await _firestore.collection('property_sales').add({
        'propertyId': propertyId,
        'sellingPrice': sellingPrice,
        'buyerId': buyerId,
        'soldDate': soldDate ?? FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Error marking property as sold', e);
      rethrow;
    }
  }

  /// تمييز العقار كمؤجر
  Future<void> markAsRented(
    String propertyId, {
    required String tenantId,
    required DateTime startDate,
    required DateTime endDate,
    required double monthlyRent,
  }) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'status': PropertyStatus.rented.toString(),
        'currentTenantId': tenantId,
        'rentStartDate': startDate,
        'rentEndDate': endDate,
        'monthlyRent': monthlyRent,
        'isAvailable': false,
      });

      // تسجيل عقد الإيجار
      await _firestore.collection('rental_contracts').add({
        'propertyId': propertyId,
        'tenantId': tenantId,
        'startDate': startDate,
        'endDate': endDate,
        'monthlyRent': monthlyRent,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Error marking property as rented', e);
      rethrow;
    }
  }

  /// تمييز العقار كمتاح
  Future<void> markAsAvailable(String propertyId) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'status': PropertyStatus.available.toString(),
        'isAvailable': true,
        'currentTenantId': FieldValue.delete(),
        'rentStartDate': FieldValue.delete(),
        'rentEndDate': FieldValue.delete(),
        'buyerId': FieldValue.delete(),
        'soldDate': FieldValue.delete(),
      });
    } catch (e) {
      logError('Error marking property as available', e);
      rethrow;
    }
  }

  /// تمييز العقار تحت العقد
  Future<void> markAsUnderContract(
    String propertyId, {
    required String contractorId,
    required DateTime contractDate,
    String? contractType,
  }) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'status': PropertyStatus.underContract.toString(),
        'contractorId': contractorId,
        'contractDate': contractDate,
        'contractType': contractType,
        'isAvailable': false,
      });

      // تسجيل العقد
      await _firestore.collection('property_contracts').add({
        'propertyId': propertyId,
        'contractorId': contractorId,
        'contractDate': contractDate,
        'contractType': contractType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Error marking property as under contract', e);
      rethrow;
    }
  }

  /// الحصول على تاريخ حالات العقار
  Future<List<DocumentSnapshot>> getStatusHistory(String propertyId) async {
    try {
      final QuerySnapshot history = await _firestore
          .collection('properties')
          .doc(propertyId)
          .collection('status_history')
          .orderBy('createdAt', descending: true)
          .get();

      return history.docs;
    } catch (e) {
      logError('Error getting status history', e);
      rethrow;
    }
  }

  /// الحصول على معرف مالك العقار
  Future<String> getPropertyOwner(String propertyId) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      return propertyDoc.get('ownerId') as String;
    } catch (e) {
      logError('Error getting property owner', e);
      rethrow;
    }
  }

  /// التحقق من حالة العقار
  Future<bool> isPropertyAvailable(String propertyId) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      final bool isAvailable = propertyDoc.get('isAvailable') ?? false;
      final bool isSuspended = propertyDoc.get('isSuspended') ?? false;

      return isAvailable && !isSuspended;
    } catch (e) {
      logError('Error checking property availability', e);
      rethrow;
    }
  }
} 