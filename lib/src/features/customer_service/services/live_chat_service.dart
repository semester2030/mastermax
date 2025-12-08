import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

class LiveChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _messagesSubscription;
  String? _currentUserId;

  Future<void> connect() async {
    _currentUserId = 'trial_user';
    // في الوضع التجريبي، نستخدم محاكاة للاتصال
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<List<ChatMessage>> getMessages() async {
    try {
      if (_currentUserId == 'trial_user') {
        return _getMockMessages();
      }

      final snapshot = await _firestore
          .collection('chats')
          .doc(_currentUserId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => ChatMessage.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      return _getMockMessages();
    }
  }

  void listenToMessages(Function(ChatMessage) onMessage) {
    if (_currentUserId == 'trial_user') {
      // في الوضع التجريبي، لا نحتاج للاستماع للرسائل
      return;
    }

    _messagesSubscription = _firestore
        .collection('chats')
        .doc(_currentUserId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final message = ChatMessage.fromJson({
            ...change.doc.data()!,
            'id': change.doc.id,
          });
          onMessage(message);
        }
      }
    });
  }

  Future<ChatMessage> sendMessage(String message) async {
    final timestamp = DateTime.now();
    final newMessage = ChatMessage(
      id: timestamp.millisecondsSinceEpoch.toString(),
      userId: _currentUserId!,
      message: message,
      isStaff: false,
      timestamp: timestamp,
    );

    if (_currentUserId != 'trial_user') {
      await _firestore
          .collection('chats')
          .doc(_currentUserId)
          .collection('messages')
          .add(newMessage.toJson());
    }

    return newMessage;
  }

  Future<ChatMessage> simulateStaffReply(String userMessage) async {
    // محاكاة رد تلقائي من فريق الدعم
    String reply = 'شكراً لتواصلك معنا! سيقوم فريق خدمة العملاء بالرد عليك في أقرب وقت.';

    if (userMessage.contains('سعر') || userMessage.contains('تكلفة')) {
      reply = 'يمكنك الاطلاع على قائمة الأسعار والباقات من خلال صفحة الأسعار في التطبيق.';
    } else if (userMessage.contains('وقت') || userMessage.contains('متى')) {
      reply = 'نحن متواجدون على مدار الساعة لخدمتك. هل تحتاج إلى مساعدة محددة؟';
    } else if (userMessage.contains('كيف') || userMessage.contains('طريقة')) {
      reply = 'يسعدنا مساعدتك! هل يمكنك توضيح ما تحتاج إليه بالتحديد؟';
    }

    final timestamp = DateTime.now();
    final staffMessage = ChatMessage(
      id: '${timestamp.millisecondsSinceEpoch}_staff',
      userId: 'staff_1',
      message: reply,
      isStaff: true,
      timestamp: timestamp,
    );

    if (_currentUserId != 'trial_user') {
      await _firestore
          .collection('chats')
          .doc(_currentUserId)
          .collection('messages')
          .add(staffMessage.toJson());
    }

    return staffMessage;
  }

  Future<ChatMessage> sendAttachment(String filePath) async {
    // TODO: Implement file upload
    throw UnimplementedError('سيتم تفعيل إرفاق الملفات قريباً');
  }

  void markAsRead(String messageId) {
    if (_currentUserId == 'trial_user') return;

    _firestore
        .collection('chats')
        .doc(_currentUserId)
        .collection('messages')
        .doc(messageId)
        .update({'read': true});
  }

  void disconnect() {
    _messagesSubscription?.cancel();
  }

  List<ChatMessage> _getMockMessages() {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: '1',
        userId: 'trial_user',
        message: 'مرحباً، أريد الاستفسار عن العقارات المتاحة',
        isStaff: false,
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
      ChatMessage(
        id: '2',
        userId: 'staff_1',
        message: 'أهلاً وسهلاً بك! يسعدني مساعدتك. هل تبحث عن عقار للإيجار أم للشراء؟',
        isStaff: true,
        timestamp: now.subtract(const Duration(minutes: 4)),
      ),
      ChatMessage(
        id: '3',
        userId: 'trial_user',
        message: 'أبحث عن شقة للإيجار في وسط المدينة',
        isStaff: false,
        timestamp: now.subtract(const Duration(minutes: 3)),
      ),
      ChatMessage(
        id: '4',
        userId: 'staff_1',
        message: 'لدينا عدة خيارات مميزة في وسط المدينة. هل لديك ميزانية محددة في ذهنك؟',
        isStaff: true,
        timestamp: now.subtract(const Duration(minutes: 2)),
      ),
    ];
  }
} 