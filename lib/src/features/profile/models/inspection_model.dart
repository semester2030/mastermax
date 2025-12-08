import 'package:cloud_firestore/cloud_firestore.dart';

class Inspection {
  final String id;
  final String propertyId;
  final String agentId;
  final String clientId;
  final DateTime scheduledDate;
  final String status;
  final String? notes;
  final Map<String, dynamic> report;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> extraData;

  Inspection({
    required this.id,
    required this.propertyId,
    required this.agentId,
    required this.clientId,
    required this.scheduledDate,
    required this.status,
    required this.createdAt, required this.updatedAt, this.notes,
    this.report = const {},
    this.extraData = const {},
  });

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      agentId: json['agentId'] as String,
      clientId: json['clientId'] as String,
      scheduledDate: (json['scheduledDate'] as Timestamp).toDate(),
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      extraData: Map<String, dynamic>.from(json['extraData'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'propertyId': propertyId,
      'agentId': agentId,
      'clientId': clientId,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': status,
      'notes': notes,
      'report': report,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'extraData': extraData,
    };
  }

  Inspection copyWith({
    String? id,
    String? propertyId,
    String? agentId,
    String? clientId,
    DateTime? scheduledDate,
    String? status,
    String? notes,
    Map<String, dynamic>? report,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? extraData,
  }) {
    return Inspection(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      agentId: agentId ?? this.agentId,
      clientId: clientId ?? this.clientId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      report: report ?? this.report,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extraData: extraData ?? this.extraData,
    );
  }
} 