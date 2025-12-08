import 'user_type.dart';

class User {
  final String id;
  final String name;
  final String email;
  final UserType type;
  final Map<String, dynamic>? extraData;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.type,
    this.extraData,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      type: UserType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => UserType.individual,
      ),
      extraData: json['extraData'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'type': type.toString(),
      'extraData': extraData,
    };
  }
} 