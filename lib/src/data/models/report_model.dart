import 'dart:convert';

enum ReportType {
  property,
  car,
  user,
  review,
  message,
  other,
}

enum ReportStatus {
  pending,
  inProgress,
  resolved,
  rejected,
}

class ReportModel {
  final String id;
  final ReportType type;
  final ReportStatus status;
  final String itemId;
  final String reporterId;
  final String reporterName;
  final String reason;
  final String description;
  final List<String>? evidence;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  ReportModel({
    required this.id,
    required this.type,
    required this.status,
    required this.itemId,
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    required this.description,
    required this.createdAt, required this.updatedAt, this.evidence,
    this.adminNote,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'itemId': itemId,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reason': reason,
      'description': description,
      'evidence': evidence,
      'adminNote': adminNote,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'] ?? '',
      type: ReportType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => ReportType.other,
      ),
      status: ReportStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => ReportStatus.pending,
      ),
      itemId: map['itemId'] ?? '',
      reporterId: map['reporterId'] ?? '',
      reporterName: map['reporterName'] ?? '',
      reason: map['reason'] ?? '',
      description: map['description'] ?? '',
      evidence: map['evidence'] != null ? List<String>.from(map['evidence']) : null,
      adminNote: map['adminNote'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      metadata: map['metadata'],
    );
  }

  String toJson() => json.encode(toMap());

  factory ReportModel.fromJson(String source) => ReportModel.fromMap(json.decode(source));

  ReportModel copyWith({
    String? id,
    ReportType? type,
    ReportStatus? status,
    String? itemId,
    String? reporterId,
    String? reporterName,
    String? reason,
    String? description,
    List<String>? evidence,
    String? adminNote,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return ReportModel(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      itemId: itemId ?? this.itemId,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      evidence: evidence ?? this.evidence,
      adminNote: adminNote ?? this.adminNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ReportModel(id: $id, type: $type, status: $status, itemId: $itemId, reporterId: $reporterId, reporterName: $reporterName, reason: $reason, description: $description, evidence: $evidence, adminNote: $adminNote, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is ReportModel &&
      other.id == id &&
      other.type == type &&
      other.status == status &&
      other.itemId == itemId &&
      other.reporterId == reporterId &&
      other.reporterName == reporterName &&
      other.reason == reason &&
      other.description == description &&
      other.evidence == evidence &&
      other.adminNote == adminNote &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.metadata == metadata;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      type.hashCode ^
      status.hashCode ^
      itemId.hashCode ^
      reporterId.hashCode ^
      reporterName.hashCode ^
      reason.hashCode ^
      description.hashCode ^
      evidence.hashCode ^
      adminNote.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      metadata.hashCode;
  }
} 