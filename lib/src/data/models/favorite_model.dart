import 'dart:convert';

enum FavoriteType {
  property,
  car,
}

class FavoriteModel {
  final String id;
  final FavoriteType type;
  final String itemId;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  FavoriteModel({
    required this.id,
    required this.type,
    required this.itemId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'itemId': itemId,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory FavoriteModel.fromMap(Map<String, dynamic> map) {
    return FavoriteModel(
      id: map['id'] ?? '',
      type: FavoriteType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => FavoriteType.property,
      ),
      itemId: map['itemId'] ?? '',
      userId: map['userId'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      metadata: map['metadata'],
    );
  }

  String toJson() => json.encode(toMap());

  factory FavoriteModel.fromJson(String source) => FavoriteModel.fromMap(json.decode(source));

  FavoriteModel copyWith({
    String? id,
    FavoriteType? type,
    String? itemId,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return FavoriteModel(
      id: id ?? this.id,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'FavoriteModel(id: $id, type: $type, itemId: $itemId, userId: $userId, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is FavoriteModel &&
      other.id == id &&
      other.type == type &&
      other.itemId == itemId &&
      other.userId == userId &&
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
      createdAt.hashCode ^
      updatedAt.hashCode ^
      metadata.hashCode;
  }
} 