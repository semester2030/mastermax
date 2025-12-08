import 'user_type.dart';

class AuthCredentials {
  final String email;
  final String password;
  final String? phoneNumber;

  AuthCredentials({
    required this.email,
    required this.password,
    this.phoneNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    };
  }
}

class RegisterCredentials extends AuthCredentials {
  final String name;
  final UserType userType;
  final Map<String, dynamic>? extraFields;

  RegisterCredentials({
    required super.email,
    required super.password,
    required this.name, required this.userType, super.phoneNumber,
    this.extraFields,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'name': name,
      'userType': userType.toString(),
      if (extraFields != null) ...extraFields!,
    };
  }
} 