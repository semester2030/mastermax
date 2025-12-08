import 'dart:convert';

enum VideoType {
  property,
  car,
  other,
}

enum VideoStatus {
  processing,
  ready,
  failed,
}

class VideoModel {
  final String id;
  final String title;
  final String description;
  final VideoType type;
  final VideoStatus status;
  final String url;
  final String thumbnailUrl;
  final int duration;
  final int size;
  final String format;
  final int width;
  final int height;
  final String itemId;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.url,
    required this.thumbnailUrl,
    required this.duration,
    required this.size,
    required this.format,
    required this.width,
    required this.height,
    required this.itemId,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'size': size,
      'format': format,
      'width': width,
      'height': height,
      'itemId': itemId,
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory VideoModel.fromMap(Map<String, dynamic> map) {
    return VideoModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: VideoType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => VideoType.other,
      ),
      status: VideoStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => VideoStatus.processing,
      ),
      url: map['url'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      duration: map['duration']?.toInt() ?? 0,
      size: map['size']?.toInt() ?? 0,
      format: map['format'] ?? '',
      width: map['width']?.toInt() ?? 0,
      height: map['height']?.toInt() ?? 0,
      itemId: map['itemId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      metadata: map['metadata'],
    );
  }

  String toJson() => json.encode(toMap());

  factory VideoModel.fromJson(String source) => VideoModel.fromMap(json.decode(source));

  VideoModel copyWith({
    String? id,
    String? title,
    String? description,
    VideoType? type,
    VideoStatus? status,
    String? url,
    String? thumbnailUrl,
    int? duration,
    int? size,
    String? format,
    int? width,
    int? height,
    String? itemId,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      size: size ?? this.size,
      format: format ?? this.format,
      width: width ?? this.width,
      height: height ?? this.height,
      itemId: itemId ?? this.itemId,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'VideoModel(id: $id, title: $title, description: $description, type: $type, status: $status, url: $url, thumbnailUrl: $thumbnailUrl, duration: $duration, size: $size, format: $format, width: $width, height: $height, itemId: $itemId, ownerId: $ownerId, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is VideoModel &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.type == type &&
      other.status == status &&
      other.url == url &&
      other.thumbnailUrl == thumbnailUrl &&
      other.duration == duration &&
      other.size == size &&
      other.format == format &&
      other.width == width &&
      other.height == height &&
      other.itemId == itemId &&
      other.ownerId == ownerId &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.metadata == metadata;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      type.hashCode ^
      status.hashCode ^
      url.hashCode ^
      thumbnailUrl.hashCode ^
      duration.hashCode ^
      size.hashCode ^
      format.hashCode ^
      width.hashCode ^
      height.hashCode ^
      itemId.hashCode ^
      ownerId.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      metadata.hashCode;
  }
} 