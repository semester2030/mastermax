import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime lastMessageTime;
  final String lastMessageText;
  final String? propertyId; // معرف العقار أو السيارة المرتبطة بالمحادثة
  final String? propertyType; // نوع العقار (عقار/سيارة)
  /// معرّف البائع في محادثة سبوتلايت (ثابت حتى مع ترتيب user1/user2 أبجدياً).
  final String? spotlightSellerId;
  final String? spotlightBuyerId;
  final String? spotlightVideoTitle;

  ChatRoom({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.lastMessageTime,
    required this.lastMessageText,
    this.propertyId,
    this.propertyType,
    this.spotlightSellerId,
    this.spotlightBuyerId,
    this.spotlightVideoTitle,
  });

  // تحويل البيانات من Firestore
  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final lastTs = data['lastMessageTime'];
    return ChatRoom(
      id: doc.id,
      user1Id: data['user1Id'] ?? '',
      user2Id: data['user2Id'] ?? '',
      lastMessageTime: lastTs is Timestamp
          ? lastTs.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      lastMessageText: data['lastMessageText'] ?? '',
      propertyId: data['propertyId'] as String?,
      propertyType: data['propertyType'] as String?,
      spotlightSellerId: data['spotlightSellerId'] as String?,
      spotlightBuyerId: data['spotlightBuyerId'] as String?,
      spotlightVideoTitle: data['spotlightVideoTitle'] as String?,
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
      if (spotlightSellerId != null) 'spotlightSellerId': spotlightSellerId,
      if (spotlightBuyerId != null) 'spotlightBuyerId': spotlightBuyerId,
      if (spotlightVideoTitle != null) 'spotlightVideoTitle': spotlightVideoTitle,
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
    String? spotlightSellerId,
    String? spotlightBuyerId,
    String? spotlightVideoTitle,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      propertyId: propertyId ?? this.propertyId,
      propertyType: propertyType ?? this.propertyType,
      spotlightSellerId: spotlightSellerId ?? this.spotlightSellerId,
      spotlightBuyerId: spotlightBuyerId ?? this.spotlightBuyerId,
      spotlightVideoTitle: spotlightVideoTitle ?? this.spotlightVideoTitle,
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