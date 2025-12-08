class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
} 