import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime lastMessageTime;
  final String lastMessageText;
  final String? propertyId; // معرف العقار أو السيارة المرتبطة بالمحادثة
  final String? propertyType; // نوع العقار (عقار/سيارة)

  ChatRoom({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.lastMessageTime,
    required this.lastMessageText,
    this.propertyId,
    this.propertyType,
  });

  // تحويل البيانات من Firestore
  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      user1Id: data['user1Id'] ?? '',
      user2Id: data['user2Id'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      lastMessageText: data['lastMessageText'] ?? '',
      propertyId: data['propertyId'],
      propertyType: data['propertyType'],
    );
  }

  // تحويل البيانات إلى Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'user1Id': user1Id,
      'user2Id': user2Id,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessageText': lastMessageText,
      'propertyId': propertyId,
      'propertyType': propertyType,
    };
  }

  // نسخ الكائن مع تعديل بعض القيم
  ChatRoom copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    DateTime? lastMessageTime,
    String? lastMessageText,
    String? propertyId,
    String? propertyType,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      propertyId: propertyId ?? this.propertyId,
      propertyType: propertyType ?? this.propertyType,
    );
  }

  // التحقق مما إذا كان المستخدم جزءاً من هذه المحادثة
  bool hasUser(String userId) {
    return user1Id == userId || user2Id == userId;
  }

  // الحصول على معرف المستخدم الآخر في المحادثة
  String getOtherUserId(String currentUserId) {
    return user1Id == currentUserId ? user2Id : user1Id;
  }
} 