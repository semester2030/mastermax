class AppConfig {
  static const String appName = 'MASTER MAX';
  static const String appVersion = '1.0.0';

  // Firebase Configuration
  static const String firebaseProjectId = 'master-max';
  
  // API Configuration
  static const String apiBaseUrl = 'https://api.mastermax.com';
  static const int apiTimeout = 30000; // 30 seconds
  
  // Map Configuration
  static const String mapApiKey = 'YOUR_MAP_API_KEY';
  static const double defaultLatitude = 24.7136;  // Default Saudi Arabia latitude
  static const double defaultLongitude = 46.6753; // Default Saudi Arabia longitude
  static const double defaultZoom = 11.0;
  
  // Cache Configuration
  static const int maxCacheAge = 7; // days
  static const int maxCacheSize = 50; // MB
  
  // Video Configuration
  static const int maxVideoDuration = 60; // seconds
  static const int maxVideoSize = 50; // MB
  
  // Pagination
  static const int defaultPageSize = 20;
  
  // Timeouts
  static const int splashScreenDuration = 2000; // milliseconds
  static const int locationTimeout = 10000; // milliseconds
  
  // Feature Flags
  static const bool enableVRFeature = true;
  static const bool enable360Feature = true;
  static const bool enableChatFeature = true;
  static const bool enableNotifications = true;
  
  // Support
  static const String supportEmail = 'support@mastermax.com';
  static const String supportPhone = '+966XXXXXXXXX';
  
  // Social Media
  static const String facebookUrl = 'https://facebook.com/mastermax';
  static const String twitterUrl = 'https://twitter.com/mastermax';
  static const String instagramUrl = 'https://instagram.com/mastermax';
  
  // Terms and Privacy
  static const String termsUrl = 'https://mastermax.com/terms';
  static const String privacyUrl = 'https://mastermax.com/privacy';
  
  // Development mode flag - set to false in production
  static bool isDevelopmentMode = true;

  // Initial route for development mode
  static String get initialRoute => '/';

  // Check if authentication is required for a route
  static bool requiresAuth(String route) {
    // These routes require authentication
    final authRequiredRoutes = [
      '/map',
      '/map-filter',
      '/properties',
      '/property-details',
      '/add-property',
    ];
    return authRequiredRoutes.contains(route);
  }
} 