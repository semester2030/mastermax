import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/logger.dart';

/// حالات الحجز
enum BookingStatus {
  /// قيد الانتظار
  pending('قيد الانتظار'),
  /// مؤكد
  confirmed('مؤكد'),
  /// ملغي
  cancelled('ملغي'),
  /// مكتمل
  completed('مكتمل');

  final String arabicName;
  const BookingStatus(this.arabicName);
}

/// نوع الحجز
enum BookingType {
  /// معاينة
  viewing('معاينة'),
  /// إيجار
  rent('إيجار'),
  /// شراء
  sale('شراء');

  final String arabicName;
  const BookingType(this.arabicName);
}

/// خدمة إدارة حجوزات العقارات
class PropertyBookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// إنشاء حجز جديد
  Future<String> createBooking({
    required String propertyId,
    required String userId,
    required DateTime dateTime,
    required BookingType type,
    String? notes,
  }) async {
    try {
      final booking = await _firestore.collection('bookings').add({
        'propertyId': propertyId,
        'userId': userId,
        'dateTime': dateTime,
        'type': type.toString(),
        'status': BookingStatus.pending.toString(),
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return booking.id;
    } catch (e) {
      logError('Error creating booking', e);
      rethrow;
    }
  }

  /// تحديث حالة الحجز
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': status.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Error updating booking status', e);
      rethrow;
    }
  }

  /// إلغاء حجز
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': BookingStatus.cancelled.toString(),
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Error cancelling booking', e);
      rethrow;
    }
  }

  /// الحصول على حجوزات عقار معين
  Future<List<DocumentSnapshot>> getPropertyBookings(
    String propertyId, {
    BookingStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('bookings')
          .where('propertyId', isEqualTo: propertyId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.toString());
      }

      if (startDate != null) {
        query = query.where('dateTime', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('dateTime', isLessThanOrEqualTo: endDate);
      }

      final QuerySnapshot result = await query.get();
      return result.docs;
    } catch (e) {
      logError('Error getting property bookings', e);
      rethrow;
    }
  }

  /// الحصول على حجوزات مستخدم معين
  Future<List<DocumentSnapshot>> getUserBookings(
    String userId, {
    BookingStatus? status,
    BookingType? type,
  }) async {
    try {
      Query query = _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.toString());
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.toString());
      }

      final QuerySnapshot result = await query.get();
      return result.docs;
    } catch (e) {
      logError('Error getting user bookings', e);
      rethrow;
    }
  }

  /// التحقق من توفر موعد
  Future<bool> isTimeSlotAvailable(
    String propertyId,
    DateTime dateTime,
  ) async {
    try {
      final startTime = dateTime.subtract(const Duration(hours: 1));
      final endTime = dateTime.add(const Duration(hours: 1));

      final QuerySnapshot result = await _firestore
          .collection('bookings')
          .where('propertyId', isEqualTo: propertyId)
          .where('dateTime', isGreaterThanOrEqualTo: startTime)
          .where('dateTime', isLessThanOrEqualTo: endTime)
          .where('status', isEqualTo: BookingStatus.confirmed.toString())
          .get();

      return result.docs.isEmpty;
    } catch (e) {
      logError('Error checking time slot availability', e);
      rethrow;
    }
  }

  /// إضافة تقييم للحجز
  Future<void> addBookingReview({
    required String bookingId,
    required double rating,
    required String comment,
  }) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'review': {
          'rating': rating,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Error adding booking review', e);
      rethrow;
    }
  }

  /// الحصول على إحصائيات الحجوزات
  Future<Map<String, int>> getBookingStatistics(String propertyId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('propertyId', isEqualTo: propertyId)
          .get();

      final Map<String, int> statistics = {
        'total': snapshot.docs.length,
        'pending': 0,
        'confirmed': 0,
        'cancelled': 0,
        'completed': 0,
      };

      for (final doc in snapshot.docs) {
        final status = doc.get('status') as String;
        final statusKey = status.split('.').last.toLowerCase();
        statistics[statusKey] = (statistics[statusKey] ?? 0) + 1;
      }

      return statistics;
    } catch (e) {
      logError('Error getting booking statistics', e);
      rethrow;
    }
  }
} 