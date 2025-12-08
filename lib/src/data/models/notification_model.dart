import 'dart:convert';

enum NotificationType {
  newProperty,
  newCar,
  newVideo,
  propertyUpdate,
  carUpdate,
  videoUpdate,
  message,
  system,
}

enum NotificationStatus {
  unread,
  read,
  archived,
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationStatus status;
  final String? imageUrl;
  final String? actionUrl;
  final String userId;
  final String? itemId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.status,
    required this.userId, required this.createdAt, required this.updatedAt, this.imageUrl,
    this.actionUrl,
    this.itemId,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'userId': userId,
      'itemId': itemId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => NotificationType.system,
      ),
      status: NotificationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => NotificationStatus.unread,
      ),
      imageUrl: map['imageUrl'],
      actionUrl: map['actionUrl'],
      userId: map['userId'] ?? '',
      itemId: map['itemId'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      metadata: map['metadata'],
    );
  }

  String toJson() => json.encode(toMap());

  factory NotificationModel.fromJson(String source) => NotificationModel.fromMap(json.decode(source));

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    NotificationStatus? status,
    String? imageUrl,
    String? actionUrl,
    String? userId,
    String? itemId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      actionUrl: actionUrl ?? this.actionUrl,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, body: $body, type: $type, status: $status, imageUrl: $imageUrl, actionUrl: $actionUrl, userId: $userId, itemId: $itemId, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is NotificationModel &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.type == type &&
      other.status == status &&
      other.imageUrl == imageUrl &&
      other.actionUrl == actionUrl &&
      other.userId == userId &&
      other.itemId == itemId &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.metadata == metadata;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      title.hashCode ^
      body.hashCode ^
      type.hashCode ^
      status.hashCode ^
      imageUrl.hashCode ^
      actionUrl.hashCode ^
      userId.hashCode ^
      itemId.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      metadata.hashCode;
  }
} 