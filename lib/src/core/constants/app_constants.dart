import 'app_brand.dart';

class AppConstants {
  // App Info
  static String get appName => AppBrand.displayName;
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // API
  static const String apiBaseUrl = 'https://api.mastermax.com';
  static const int apiTimeout = 30000; // 30 seconds
  static const int maxRetries = 3;

  // Cache
  static const String cachePrefix = 'mastermax_cache';
  static const int cacheDuration = 7; // 7 days
  static const int maxCacheSize = 100 * 1024 * 1024; // 100 MB

  // Authentication
  static const int otpLength = 6;
  static const int otpDuration = 300; // 5 minutes
  static const int maxLoginAttempts = 5;
  static const int lockoutDuration = 1800; // 30 minutes

  // Validation
  static const String emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String phonePattern = r'^(05)[0-9]{8}$';
  static const String passwordPattern = r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$';
  static const String requiredField = 'هذا الحقل مطلوب';
  static const String invalidEmail = 'البريد الإلكتروني غير صالح';
  static const String invalidPhone = 'رقم الجوال غير صالح';
  static const String invalidPassword = 'كلمة المرور يجب أن تحتوي على 8 أحرف على الأقل وتتضمن حروف وأرقام';

  // Pagination
  static const int pageSize = 20;
  static const int maxPages = 100;

  // Media
  static const int maxImageSize = 5 * 1024 * 1024; // 5 MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100 MB
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;
  static const int maxVideoDuration = 300; // 5 minutes
  static const List<String> allowedImageTypes = ['.jpg', '.jpeg', '.png', '.webp'];
  static const List<String> allowedVideoTypes = ['.mp4', '.mov', '.avi'];

  // Listings
  static const int maxImagesPerProperty = 20;
  static const int maxImagesPerCar = 20;
  static const int maxVideosPerProperty = 2;
  static const int maxVideosPerCar = 2;
  static const int minPropertyPrice = 1000;
  static const int maxPropertyPrice = 100000000;
  static const int minCarPrice = 1000;
  static const int maxCarPrice = 10000000;

  // Reviews
  static const int minReviewLength = 10;
  static const int maxReviewLength = 500;
  static const int minRating = 1;
  static const int maxRating = 5;

  // Messages
  static const int maxMessageLength = 1000;
  static const int maxAttachmentsPerMessage = 5;

  // Notifications
  static const int maxNotificationRetention = 30; // 30 days

  // Analytics
  static const int analyticsRetention = 365; // 1 year
  static const int maxEventsPerSession = 100;

  // Error Messages
  static const String networkError = 'تعذر الاتصال بالإنترنت';
  static const String serverError = 'حدث خطأ في الخادم';
  static const String timeoutError = 'انتهت مهلة الاتصال';
  static const String unknownError = 'حدث خطأ غير معروف';

  // Success Messages
  static const String saveSuccess = 'تم الحفظ بنجاح';
  static const String updateSuccess = 'تم التحديث بنجاح';
  static const String deleteSuccess = 'تم الحذف بنجاح';

  // Confirmation Messages
  static const String deleteConfirmation = 'هل أنت متأكد من الحذف؟';
  static const String logoutConfirmation = 'هل أنت متأكد من تسجيل الخروج؟';

  // Button Text
  static const String confirm = 'تأكيد';
  static const String cancel = 'إلغاء';
  static const String save = 'حفظ';
  static const String edit = 'تعديل';
  static const String delete = 'حذف';
  static const String close = 'إغلاق';
  static const String retry = 'إعادة المحاولة';
} 