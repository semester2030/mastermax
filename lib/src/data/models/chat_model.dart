import 'dart:convert';

enum ChatType {
  direct,
  group,
  support,
}

enum ChatStatus {
  active,
  archived,
  blocked,
}

class ChatModel {
  final String id;
  final ChatType type;
  final ChatStatus status;
  final String title;
  final String? imageUrl;
  final List<String> participantIds;
  final String lastMessageId;
  final String lastMessageContent;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  ChatModel({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.participantIds, required this.lastMessageId, required this.lastMessageContent, required this.lastMessageTime, required this.unreadCount, required this.isDeleted, required this.createdAt, required this.updatedAt, this.imageUrl,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'title': title,
      'imageUrl': imageUrl,
      'participantIds': participantIds,
      'lastMessageId': lastMessageId,
      'lastMessageContent': lastMessageContent,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id'] ?? '',
      type: ChatType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => ChatType.direct,
      ),
      status: ChatStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => ChatStatus.active,
      ),
      title: map['title'] ?? '',
      imageUrl: map['imageUrl'],
      participantIds: List<String>.from(map['participantIds'] ?? []),
      lastMessageId: map['lastMessageId'] ?? '',
      lastMessageContent: map['lastMessageContent'] ?? '',
      lastMessageTime: DateTime.parse(map['lastMessageTime']),
      unreadCount: map['unreadCount']?.toInt() ?? 0,
      isDeleted: map['isDeleted'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      metadata: map['metadata'],
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatModel.fromJson(String source) => ChatModel.fromMap(json.decode(source));

  ChatModel copyWith({
    String? id,
    ChatType? type,
    ChatStatus? status,
    String? title,
    String? imageUrl,
    List<String>? participantIds,
    String? lastMessageId,
    String? lastMessageContent,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return ChatModel(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      participantIds: participantIds ?? this.participantIds,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ChatModel(id: $id, type: $type, status: $status, title: $title, imageUrl: $imageUrl, participantIds: $participantIds, lastMessageId: $lastMessageId, lastMessageContent: $lastMessageContent, lastMessageTime: $lastMessageTime, unreadCount: $unreadCount, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is ChatModel &&
      other.id == id &&
      other.type == type &&
      other.status == status &&
      other.title == title &&
      other.imageUrl == imageUrl &&
      other.participantIds == participantIds &&
      other.lastMessageId == lastMessageId &&
      other.lastMessageContent == lastMessageContent &&
      other.lastMessageTime == lastMessageTime &&
      other.unreadCount == unreadCount &&
      other.isDeleted == isDeleted &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.metadata == metadata;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      type.hashCode ^
      status.hashCode ^
      title.hashCode ^
      imageUrl.hashCode ^
      participantIds.hashCode ^
      lastMessageId.hashCode ^
      lastMessageContent.hashCode ^
      lastMessageTime.hashCode ^
      unreadCount.hashCode ^
      isDeleted.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      metadata.hashCode;
  }
} 