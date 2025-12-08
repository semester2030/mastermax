import 'dart:convert';

enum StatsType {
  daily,
  weekly,
  monthly,
  yearly,
}

enum StatsCategory {
  users,
  properties,
  cars,
  videos,
  messages,
  reviews,
  reports,
  ads,
}

class StatsModel {
  final String id;
  final StatsType type;
  final StatsCategory category;
  final DateTime date;
  final int totalCount;
  final int activeCount;
  final int newCount;
  final int deletedCount;
  final double totalValue;
  final Map<String, int> breakdown;
  final Map<String, double> metrics;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  StatsModel({
    required this.id,
    required this.type,
    required this.category,
    required this.date,
    required this.totalCount,
    required this.activeCount,
    required this.newCount,
    required this.deletedCount,
    required this.totalValue,
    required this.breakdown,
    required this.metrics,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'category': category.toString().split('.').last,
      'date': date.toIso8601String(),
      'totalCount': totalCount,
      'activeCount': activeCount,
      'newCount': newCount,
      'deletedCount': deletedCount,
      'totalValue': totalValue,
      'breakdown': breakdown,
      'metrics': metrics,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory StatsModel.fromMap(Map<String, dynamic> map) {
    return StatsModel(
      id: map['id'] ?? '',
      type: StatsType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => StatsType.daily,
      ),
      category: StatsCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => StatsCategory.users,
      ),
      date: DateTime.parse(map['date']),
      totalCount: map['totalCount']?.toInt() ?? 0,
      activeCount: map['activeCount']?.toInt() ?? 0,
      newCount: map['newCount']?.toInt() ?? 0,
      deletedCount: map['deletedCount']?.toInt() ?? 0,
      totalValue: map['totalValue']?.toDouble() ?? 0.0,
      breakdown: Map<String, int>.from(map['breakdown'] ?? {}),
      metrics: Map<String, double>.from(map['metrics'] ?? {}),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      metadata: map['metadata'],
    );
  }

  String toJson() => json.encode(toMap());

  factory StatsModel.fromJson(String source) => StatsModel.fromMap(json.decode(source));

  StatsModel copyWith({
    String? id,
    StatsType? type,
    StatsCategory? category,
    DateTime? date,
    int? totalCount,
    int? activeCount,
    int? newCount,
    int? deletedCount,
    double? totalValue,
    Map<String, int>? breakdown,
    Map<String, double>? metrics,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return StatsModel(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      totalCount: totalCount ?? this.totalCount,
      activeCount: activeCount ?? this.activeCount,
      newCount: newCount ?? this.newCount,
      deletedCount: deletedCount ?? this.deletedCount,
      totalValue: totalValue ?? this.totalValue,
      breakdown: breakdown ?? this.breakdown,
      metrics: metrics ?? this.metrics,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'StatsModel(id: $id, type: $type, category: $category, date: $date, totalCount: $totalCount, activeCount: $activeCount, newCount: $newCount, deletedCount: $deletedCount, totalValue: $totalValue, breakdown: $breakdown, metrics: $metrics, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is StatsModel &&
      other.id == id &&
      other.type == type &&
      other.category == category &&
      other.date == date &&
      other.totalCount == totalCount &&
      other.activeCount == activeCount &&
      other.newCount == newCount &&
      other.deletedCount == deletedCount &&
      other.totalValue == totalValue &&
      other.breakdown == breakdown &&
      other.metrics == metrics &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.metadata == metadata;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      type.hashCode ^
      category.hashCode ^
      date.hashCode ^
      totalCount.hashCode ^
      activeCount.hashCode ^
      newCount.hashCode ^
      deletedCount.hashCode ^
      totalValue.hashCode ^
      breakdown.hashCode ^
      metrics.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      metadata.hashCode;
  }
} 