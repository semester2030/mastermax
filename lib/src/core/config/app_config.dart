import '../constants/app_brand.dart';

class AppConfig {
  static String get appName => AppBrand.displayName;
  static const String appVersion = '1.0.0';

  // Firebase Configuration
  static const String firebaseProjectId = 'reca';
  
  // API Configuration
  static const String apiBaseUrl = 'https://api.reca.com';
  static const int apiTimeout = 30000; // 30 seconds
  
  /// Google Maps / Places / Geocoding (REST). Prefer `--dart-define=GOOGLE_MAPS_API_KEY=...` in CI;
  /// restrict the key in Google Cloud Console (iOS bundle ID, Android package + SHA-1, API allowlist).
  static String get mapApiKey {
    const fromEnv = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _mapApiKeyDefault;
  }

  static const String _mapApiKeyDefault =
      'AIzaSyDqTUgEpUZmwM602S6TVc57d5erB_c-dr4';
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
  static const String supportEmail = 'support@reca.com';
  static const String supportPhone = '+966XXXXXXXXX';
  
  // Social Media
  static const String facebookUrl = 'https://facebook.com/reca';
  static const String twitterUrl = 'https://twitter.com/reca';
  static const String instagramUrl = 'https://instagram.com/reca';
  
  // Terms and Privacy
  static const String termsUrl = 'https://reca.com/terms';
  static const String privacyUrl = 'https://reca.com/privacy';
  
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