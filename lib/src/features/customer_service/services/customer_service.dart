import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/support_ticket.dart';

class CustomerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<SupportTicket>> getTickets() async {
    try {
      final snapshot = await _firestore
          .collection('support_tickets')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SupportTicket.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('فشل في جلب التذاكر: ${e.toString()}');
    }
  }

  Future<SupportTicket> getTicketById(String ticketId) async {
    try {
      final doc = await _firestore
          .collection('support_tickets')
          .doc(ticketId)
          .get();

      if (!doc.exists) {
        throw Exception('التذكرة غير موجودة');
      }

      return SupportTicket.fromFirestore(doc);
    } catch (e) {
      throw Exception('فشل في جلب التذكرة: ${e.toString()}');
    }
  }

  Future<SupportTicket> createTicket({
    required String userId,
    required String title,
    required String description,
  }) async {
    try {
      final ticket = SupportTicket(
        id: '',
        userId: userId,
        title: title,
        description: description,
        status: TicketStatus.open,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('support_tickets')
          .add(ticket.toFirestore());

      return ticket.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('فشل في إنشاء التذكرة: ${e.toString()}');
    }
  }

  Future<SupportTicket> updateTicketStatus(
    String ticketId,
    TicketStatus status,
  ) async {
    try {
      await _firestore.collection('support_tickets').doc(ticketId).update({
        'status': status.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final doc = await _firestore
          .collection('support_tickets')
          .doc(ticketId)
          .get();

      return SupportTicket.fromFirestore(doc);
    } catch (e) {
      throw Exception('فشل في تحديث حالة التذكرة: ${e.toString()}');
    }
  }

  Future<SupportTicket> addResponse(
    String ticketId,
    String response,
    String agentId,
  ) async {
    try {
      await _firestore.collection('support_tickets').doc(ticketId).update({
        'response': response,
        'agentId': agentId,
        'status': TicketStatus.inProgress.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final doc = await _firestore
          .collection('support_tickets')
          .doc(ticketId)
          .get();

      return SupportTicket.fromFirestore(doc);
    } catch (e) {
      throw Exception('فشل في إضافة الرد: ${e.toString()}');
    }
  }

  Future<void> deleteTicket(String ticketId) async {
    try {
      await _firestore.collection('support_tickets').doc(ticketId).delete();
    } catch (e) {
      throw Exception('فشل في حذف التذكرة: ${e.toString()}');
    }
  }
} 