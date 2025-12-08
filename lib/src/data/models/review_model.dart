import 'dart:convert';

enum ReviewType {
  property,
  car,
  user,
}

class ReviewModel {
  final String id;
  final ReviewType type;
  final String itemId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final double rating;
  final String comment;
  final List<String>? images;
  final bool isVerified;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  ReviewModel({
    required this.id,
    required this.type,
    required this.itemId,
    required this.userId,
    required this.userName,
    required this.rating, required this.comment, required this.isVerified, required this.isDeleted, required this.createdAt, required this.updatedAt, this.userAvatar,
    this.images,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'itemId': itemId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'rating': rating,
      'comment': comment,
      'images': images,
      'isVerified': isVerified,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: map['id'] ?? '',
      type: ReviewType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => ReviewType.user,
      ),
      itemId: map['itemId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userAvatar: map['userAvatar'],
      rating: map['rating']?.toDouble() ?? 0.0,
      comment: map['comment'] ?? '',
      images: map['images'] != null ? List<String>.from(map['images']) : null,
      isVerified: map['isVerified'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      metadata: map['metadata'],
    );
  }

  String toJson() => json.encode(toMap());

  factory ReviewModel.fromJson(String source) => ReviewModel.fromMap(json.decode(source));

  ReviewModel copyWith({
    String? id,
    ReviewType? type,
    String? itemId,
    String? userId,
    String? userName,
    String? userAvatar,
    double? rating,
    String? comment,
    List<String>? images,
    bool? isVerified,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      images: images ?? this.images,
      isVerified: isVerified ?? this.isVerified,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ReviewModel(id: $id, type: $type, itemId: $itemId, userId: $userId, userName: $userName, userAvatar: $userAvatar, rating: $rating, comment: $comment, images: $images, isVerified: $isVerified, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is ReviewModel &&
      other.id == id &&
      other.type == type &&
      other.itemId == itemId &&
      other.userId == userId &&
      other.userName == userName &&
      other.userAvatar == userAvatar &&
      other.rating == rating &&
      other.comment == comment &&
      other.images == images &&
      other.isVerified == isVerified &&
      other.isDeleted == isDeleted &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.metadata == metadata;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      type.hashCode ^
      itemId.hashCode ^
      userId.hashCode ^
      userName.hashCode ^
      userAvatar.hashCode ^
      rating.hashCode ^
      comment.hashCode ^
      images.hashCode ^
      isVerified.hashCode ^
      isDeleted.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      metadata.hashCode;
  }
} 