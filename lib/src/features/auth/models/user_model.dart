import 'user_type.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final UserType userType;
  final String? profileImage;
  final DateTime createdAt;
  final bool isVerified;
  final Map<String, dynamic>? additionalInfo;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.userType,
    required this.createdAt, this.profileImage,
    this.isVerified = false,
    this.additionalInfo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      userType: UserType.values.firstWhere(
        (e) => e.toString() == 'UserType.${json['userType']}',
        orElse: () => UserType.individual,
      ),
      profileImage: json['profileImage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isVerified: json['isVerified'] as bool? ?? false,
      additionalInfo: json['additionalInfo'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'userType': userType.toString().split('.').last,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
      'isVerified': isVerified,
      'additionalInfo': additionalInfo,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    UserType? userType,
    String? profileImage,
    DateTime? createdAt,
    bool? isVerified,
    Map<String, dynamic>? additionalInfo,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userType: userType ?? this.userType,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }
} 