import 'dart:convert';

enum AdType {
  banner,
  interstitial,
  video,
  native,
}

enum AdStatus {
  active,
  paused,
  ended,
}

enum AdPlacement {
  home,
  search,
  details,
  profile,
  chat,
}

class AdModel {
  final String id;
  final String title;
  final String description;
  final AdType type;
  final AdStatus status;
  final AdPlacement placement;
  final String imageUrl;
  final String? videoUrl;
  final String? actionUrl;
  final DateTime startDate;
  final DateTime endDate;
  final int impressions;
  final int clicks;
  final double budget;
  final double spent;
  final String advertiserId;
  final String advertiserName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  AdModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.placement,
    required this.imageUrl,
    required this.startDate, required this.endDate, required this.impressions, required this.clicks, required this.budget, required this.spent, required this.advertiserId, required this.advertiserName, required this.isActive, required this.createdAt, required this.updatedAt, this.videoUrl,
    this.actionUrl,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'placement': placement.toString().split('.').last,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'actionUrl': actionUrl,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'impressions': impressions,
      'clicks': clicks,
      'budget': budget,
      'spent': spent,
      'advertiserId': advertiserId,
      'advertiserName': advertiserName,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory AdModel.fromMap(Map<String, dynamic> map) {
    return AdModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: AdType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => AdType.banner,
      ),
      status: AdStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => AdStatus.active,
      ),
      placement: AdPlacement.values.firstWhere(
        (e) => e.toString().split('.').last == map['placement'],
        orElse: () => AdPlacement.home,
      ),
      imageUrl: map['imageUrl'] ?? '',
      videoUrl: map['videoUrl'],
      actionUrl: map['actionUrl'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      impressions: map['impressions']?.toInt() ?? 0,
      clicks: map['clicks']?.toInt() ?? 0,
      budget: map['budget']?.toDouble() ?? 0.0,
      spent: map['spent']?.toDouble() ?? 0.0,
      advertiserId: map['advertiserId'] ?? '',
      advertiserName: map['advertiserName'] ?? '',
      isActive: map['isActive'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      metadata: map['metadata'],
    );
  }

  String toJson() => json.encode(toMap());

  factory AdModel.fromJson(String source) => AdModel.fromMap(json.decode(source));

  AdModel copyWith({
    String? id,
    String? title,
    String? description,
    AdType? type,
    AdStatus? status,
    AdPlacement? placement,
    String? imageUrl,
    String? videoUrl,
    String? actionUrl,
    DateTime? startDate,
    DateTime? endDate,
    int? impressions,
    int? clicks,
    double? budget,
    double? spent,
    String? advertiserId,
    String? advertiserName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return AdModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      placement: placement ?? this.placement,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      actionUrl: actionUrl ?? this.actionUrl,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      impressions: impressions ?? this.impressions,
      clicks: clicks ?? this.clicks,
      budget: budget ?? this.budget,
      spent: spent ?? this.spent,
      advertiserId: advertiserId ?? this.advertiserId,
      advertiserName: advertiserName ?? this.advertiserName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'AdModel(id: $id, title: $title, description: $description, type: $type, status: $status, placement: $placement, imageUrl: $imageUrl, videoUrl: $videoUrl, actionUrl: $actionUrl, startDate: $startDate, endDate: $endDate, impressions: $impressions, clicks: $clicks, budget: $budget, spent: $spent, advertiserId: $advertiserId, advertiserName: $advertiserName, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is AdModel &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.type == type &&
      other.status == status &&
      other.placement == placement &&
      other.imageUrl == imageUrl &&
      other.videoUrl == videoUrl &&
      other.actionUrl == actionUrl &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.impressions == impressions &&
      other.clicks == clicks &&
      other.budget == budget &&
      other.spent == spent &&
      other.advertiserId == advertiserId &&
      other.advertiserName == advertiserName &&
      other.isActive == isActive &&
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
      placement.hashCode ^
      imageUrl.hashCode ^
      videoUrl.hashCode ^
      actionUrl.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      impressions.hashCode ^
      clicks.hashCode ^
      budget.hashCode ^
      spent.hashCode ^
      advertiserId.hashCode ^
      advertiserName.hashCode ^
      isActive.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      metadata.hashCode;
  }
} 