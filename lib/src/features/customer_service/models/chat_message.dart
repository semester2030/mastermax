import 'package:intl/intl.dart';

class ChatMessage {
  final String id;
  final String userId;
  final String message;
  final bool isStaff;
  final DateTime timestamp;
  final List<String> attachments;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.message,
    required this.isStaff,
    required this.timestamp,
    this.attachments = const [],
  });

  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return DateFormat.jm().format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'الأمس ${DateFormat.jm().format(timestamp)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
    }
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      userId: json['userId'],
      message: json['message'],
      isStaff: json['isStaff'],
      timestamp: DateTime.parse(json['timestamp']),
      attachments: List<String>.from(json['attachments'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'message': message,
      'isStaff': isStaff,
      'timestamp': timestamp.toIso8601String(),
      'attachments': attachments,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? userId,
    String? message,
    bool? isStaff,
    DateTime? timestamp,
    List<String>? attachments,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      message: message ?? this.message,
      isStaff: isStaff ?? this.isStaff,
      timestamp: timestamp ?? this.timestamp,
      attachments: attachments ?? this.attachments,
    );
  }
} 