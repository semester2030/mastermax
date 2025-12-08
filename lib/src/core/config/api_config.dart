class ApiConfig {
  static const String baseUrl = 'https://api.mastermax.com';  // قم بتغيير هذا إلى عنوان API الخاص بك
  static const String apiVersion = 'v1';
  
  // API Endpoints
  static String get businessEndpoint => '$baseUrl/$apiVersion/business';
  static String get profileEndpoint => '$baseUrl/$apiVersion/profile';
  static String get realEstateEndpoint => '$baseUrl/$apiVersion/real-estate';
  
  // API Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // API Timeouts
  static const int connectionTimeout = 30000;  // 30 seconds
  static const int receiveTimeout = 30000;     // 30 seconds
} 