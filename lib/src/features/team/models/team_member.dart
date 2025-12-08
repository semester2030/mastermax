import 'package:equatable/equatable.dart';

class TeamMember extends Equatable {
  final String id;
  final String name;
  final String email;
  final String role;
  final List<String> permissions;
  final DateTime createdAt;
  final bool isActive;

  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    required this.createdAt,
    this.isActive = true,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      permissions: List<String>.from(json['permissions'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'permissions': permissions,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  @override
  List<Object?> get props => [id, name, email, role, permissions, createdAt, isActive];
} 