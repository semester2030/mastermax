import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/support_ticket.dart';

class CustomerServiceProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<SupportTicket> _tickets = [];
  String? _error;
  bool _isLoading = false;

  List<SupportTicket> get tickets => _tickets;
  String? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> loadTickets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _error = 'يجب تسجيل الدخول لعرض تذاكر الدعم';
        return;
      }

      final snapshot = await _firestore
          .collection('support_tickets')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      _tickets = snapshot.docs
          .map((doc) => SupportTicket.fromFirestore(doc))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTicket({
    required String title,
    required String description,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('يجب تسجيل الدخول لإنشاء تذكرة');
      }

      final ticket = SupportTicket(
        id: '',
        userId: uid,
        title: title,
        description: description,
        status: TicketStatus.open,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('support_tickets')
          .add(ticket.toFirestore());

      final newTicket = ticket.copyWith(id: docRef.id);
      _tickets.insert(0, newTicket);
      notifyListeners();
    } catch (e) {
      throw Exception('فشل في إنشاء التذكرة: ${e.toString()}');
    }
  }

  Future<void> updateTicketStatus(String ticketId, TicketStatus status) async {
    try {
      await _firestore.collection('support_tickets').doc(ticketId).update({
        'status': status.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final index = _tickets.indexWhere((t) => t.id == ticketId);
      if (index != -1) {
        _tickets[index] = _tickets[index].copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      throw Exception('فشل في تحديث حالة التذكرة: ${e.toString()}');
    }
  }

  Future<void> addResponse(String ticketId, String response) async {
    try {
      await _firestore.collection('support_tickets').doc(ticketId).update({
        'response': response,
        'status': TicketStatus.inProgress.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final index = _tickets.indexWhere((t) => t.id == ticketId);
      if (index != -1) {
        _tickets[index] = _tickets[index].copyWith(
          response: response,
          status: TicketStatus.inProgress,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      throw Exception('فشل في إضافة الرد: ${e.toString()}');
    }
  }

  Future<void> closeTicket(String ticketId) async {
    try {
      await _firestore.collection('support_tickets').doc(ticketId).update({
        'status': TicketStatus.closed.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final index = _tickets.indexWhere((t) => t.id == ticketId);
      if (index != -1) {
        _tickets[index] = _tickets[index].copyWith(
          status: TicketStatus.closed,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      throw Exception('فشل في إغلاق التذكرة: ${e.toString()}');
    }
  }

  Future<void> deleteTicket(String ticketId) async {
    try {
      await _firestore.collection('support_tickets').doc(ticketId).delete();

      _tickets.removeWhere((t) => t.id == ticketId);
      notifyListeners();
    } catch (e) {
      throw Exception('فشل في حذف التذكرة: ${e.toString()}');
    }
  }
} 