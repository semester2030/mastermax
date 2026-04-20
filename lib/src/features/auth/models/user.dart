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
    // دعم كلا الحقلين: 'type' و 'userType'
    String? typeString;
    if (json['type'] != null) {
      typeString = json['type'].toString();
    } else if (json['userType'] != null) {
      typeString = json['userType'].toString();
    }
    
    UserType userType = UserType.individual;
    if (typeString != null) {
      // محاولة مطابقة مع 'UserType.xxx' أو 'xxx'
      final cleanType = typeString.replaceAll('UserType.', '');
      userType = UserType.values.firstWhere(
        (e) => e.toString().split('.').last == cleanType || 
              e.toString() == typeString,
        orElse: () => UserType.individual,
      );
    }
    
    return User(
      id: json['id'] ?? json['uid'] ?? '',
      name: json['name'] ?? json['displayName'] ?? '',
      email: json['email'] ?? '',
      type: userType,
      extraData: json['extraData'] ?? json,
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

  User copyWith({
    String? id,
    String? name,
    String? email,
    UserType? type,
    Map<String, dynamic>? extraData,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      type: type ?? this.type,
      extraData: extraData ?? this.extraData,
    );
  }
} 