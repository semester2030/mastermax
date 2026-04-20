import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// معرف مستند ثابت: محادثة واحدة لكل (مشتري، بائع، فيديو سبوتلايت).
  /// يضمن عدم دمج محادثات مقاطع مختلفة لنفس الشخصين.
  static String spotlightRoomDocumentId(
    String buyerId,
    String sellerId,
    String videoId,
  ) {
    final ids = [buyerId, sellerId]..sort();
    final safeVideo =
        videoId.replaceAll('/', '_').replaceAll('\\', '_').replaceAll(' ', '_');
    final base = 'sv_${safeVideo}_${ids[0]}_${ids[1]}';
    if (base.length > 800) {
      return 'sv_${ids[0]}_${ids[1]}_${safeVideo.hashCode.abs()}';
    }
    return base;
  }

  /// غرفة دردشة مرتبطة بمقطع سبوتلايت محدد (عميل ↔ صاحب الإعلان).
  Future<ChatRoom> createOrGetSpotlightVideoRoom({
    required String buyerId,
    required String sellerId,
    required String videoId,
    required String propertyType,
    String? videoTitle,
  }) async {
    final b = buyerId.trim();
    final s = sellerId.trim();
    final v = videoId.trim();
    if (b.isEmpty || s.isEmpty || v.isEmpty) {
      throw ArgumentError('buyerId, sellerId, videoId مطلوبة');
    }
    if (b == s) {
      throw ArgumentError('لا يمكن فتح محادثة مع نفس المستخدم');
    }

    final roomId = spotlightRoomDocumentId(b, s, v);
    final ref = _firestore.collection('chatRooms').doc(roomId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        final sorted = [buyerId, sellerId]..sort();
        final vt = videoTitle?.trim();
        tx.set(ref, {
          'user1Id': sorted[0],
          'user2Id': sorted[1],
          'lastMessageTime': Timestamp.fromDate(DateTime.now()),
          'lastMessageText': '',
          'propertyId': videoId,
          'propertyType': propertyType,
          'spotlightBuyerId': buyerId,
          'spotlightSellerId': sellerId,
          if (vt != null && vt.isNotEmpty) 'spotlightVideoTitle': vt,
        });
      }
    });

    final created = await ref.get();
    return ChatRoom.fromFirestore(created);
  }

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

          // دمج النتائج (بدون تكرار لنفس مستند الغرفة)
          final byId = <String, ChatRoom>{};
          for (final doc in snapshot1.docs) {
            final r = ChatRoom.fromFirestore(doc);
            byId[r.id] = r;
          }
          for (final doc in snapshot2.docs) {
            final r = ChatRoom.fromFirestore(doc);
            byId[r.id] = r;
          }
          final merged = byId.values.toList();
          merged.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return merged;
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