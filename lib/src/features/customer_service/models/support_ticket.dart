import 'package:cloud_firestore/cloud_firestore.dart';

enum TicketStatus {
  open,
  inProgress,
  resolved,
  closed,
}

class SupportTicket {
  final String id;
  final String userId;
  final String title;
  final String description;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? response;
  final String? agentId;

  const SupportTicket({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.response,
    this.agentId,
  });

  factory SupportTicket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupportTicket(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      status: TicketStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => TicketStatus.open,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      response: data['response'] as String?,
      agentId: data['agentId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'response': response,
      'agentId': agentId,
    };
  }

  SupportTicket copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    TicketStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? response,
    String? agentId,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      response: response ?? this.response,
      agentId: agentId ?? this.agentId,
    );
  }
} 