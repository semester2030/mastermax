import 'dart:convert';

enum MessageType {
  text,
  image,
  video,
  location,
  system,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final MessageType type;
  final MessageStatus status;
  final String content;
  final String? imageUrl;
  final String? videoUrl;
  final double? latitude;
  final double? longitude;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.status,
    required this.content,
    required this.isDeleted, required this.createdAt, required this.updatedAt, this.imageUrl,
    this.videoUrl,
    this.latitude,
    this.longitude,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'content': content,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => MessageStatus.sending,
      ),
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      videoUrl: map['videoUrl'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      isDeleted: map['isDeleted'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      metadata: map['metadata'],
    );
  }

  String toJson() => json.encode(toMap());

  factory MessageModel.fromJson(String source) => MessageModel.fromMap(json.decode(source));

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? receiverId,
    MessageType? type,
    MessageStatus? status,
    String? content,
    String? imageUrl,
    String? videoUrl,
    double? latitude,
    double? longitude,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      type: type ?? this.type,
      status: status ?? this.status,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, chatId: $chatId, senderId: $senderId, receiverId: $receiverId, type: $type, status: $status, content: $content, imageUrl: $imageUrl, videoUrl: $videoUrl, latitude: $latitude, longitude: $longitude, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is MessageModel &&
      other.id == id &&
      other.chatId == chatId &&
      other.senderId == senderId &&
      other.receiverId == receiverId &&
      other.type == type &&
      other.status == status &&
      other.content == content &&
      other.imageUrl == imageUrl &&
      other.videoUrl == videoUrl &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.isDeleted == isDeleted &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.metadata == metadata;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      chatId.hashCode ^
      senderId.hashCode ^
      receiverId.hashCode ^
      type.hashCode ^
      status.hashCode ^
      content.hashCode ^
      imageUrl.hashCode ^
      videoUrl.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      isDeleted.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      metadata.hashCode;
  }
} 