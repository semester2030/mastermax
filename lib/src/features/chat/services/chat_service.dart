import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // إنشاء أو الحصول على غرفة محادثة
  Future<ChatRoom> createOrGetChatRoom({
    required String currentUserId,
    required String otherUserId,
    String? propertyId,
    String? propertyType,
  }) async {
    // البحث عن محادثة موجودة
    final querySnapshot = await _firestore.collection('chatRooms')
        .where('user1Id', whereIn: [currentUserId, otherUserId])
        .where('user2Id', whereIn: [currentUserId, otherUserId])
        .get();

    // إذا وجدت محادثة موجودة
    if (querySnapshot.docs.isNotEmpty) {
      return ChatRoom.fromFirestore(querySnapshot.docs.first);
    }

    // إنشاء محادثة جديدة
    final newChatRoom = ChatRoom(
      id: '',
      user1Id: currentUserId,
      user2Id: otherUserId,
      lastMessageTime: DateTime.now(),
      lastMessageText: '',
      propertyId: propertyId,
      propertyType: propertyType,
    );

    final docRef = await _firestore.collection('chatRooms')
        .add(newChatRoom.toFirestore());
    
    return newChatRoom.copyWith(id: docRef.id);
  }

  // إرسال رسالة
  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String text,
  }) async {
    final message = ChatMessage(
      id: '',
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
    );

    final batch = _firestore.batch();
    
    // إضافة الرسالة
    final messageRef = _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc();
    batch.set(messageRef, message.toFirestore());

    // تحديث آخر رسالة في المحادثة
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    batch.update(chatRoomRef, {
      'lastMessageText': text,
      'lastMessageTime': Timestamp.fromDate(DateTime.now()),
    });

    await batch.commit();
  }

  // الحصول على قائمة المحادثات للمستخدم
  Stream<List<ChatRoom>> getChatRooms(String userId) {
    // نحتاج للحصول على المحادثات حيث المستخدم إما user1Id أو user2Id
    return _firestore
        .collection('chatRooms')
        .where('user1Id', isEqualTo: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot1) async {
          // الحصول على المحادثات حيث المستخدم هو user2Id
          final snapshot2 = await _firestore
              .collection('chatRooms')
              .where('user2Id', isEqualTo: userId)
              .orderBy('lastMessageTime', descending: true)
              .get();

          // دمج النتائج
          final allRooms = [
            ...snapshot1.docs.map((doc) => ChatRoom.fromFirestore(doc)),
            ...snapshot2.docs.map((doc) => ChatRoom.fromFirestore(doc)),
          ];

          // ترتيب حسب آخر رسالة
          allRooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          
          return allRooms;
        });
  }

  // الحصول على رسائل المحادثة
  Stream<List<ChatMessage>> getChatMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }
} 