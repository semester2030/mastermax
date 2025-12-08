class Routes {
  // الصفحة الرئيسية
  static const String home = '/';
  static const String mapFilters = '/filters';
  static const String locationPicker = '/location-picker';

  // المصادقة
  static const String auth = '/auth';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String companyRegister = '/auth/company-register';
  static const String otp = '/auth/otp';
  static const String resetPassword = '/auth/reset-password';

  // العقارات
  static const String properties = '/properties';
  static const String propertiesList = '/properties/list';
  static const String propertyDetails = '/properties/details/';
  static const String addProperty = '/properties/add';
  static const String editProperty = '/properties/edit/';
  static const String propertyMedia = '/properties/media/';
  static const String propertyVR = '/properties/vr/';
  static const String property360View = '/property-360-view';
  static const String propertyVirtualTour = '/property-virtual-tour';

  // السيارات
  static const String cars = '/cars';
  static const String carsList = '/cars/list';
  static const String carDetails = '/cars/details/';
  static const String addCar = '/cars/add';
  static const String editCar = '/cars/edit/';
  static const String carMedia = '/cars/media/';
  static const String car360View = '/car-360-view';
  static const String carVirtualTour = '/car-virtual-tour';

  // أضواء ماكس
  static const String spotlight = '/spotlight';
  static const String spotlightFeed = '/spotlight/feed';
  static const String videoUpload = '/spotlight/upload';
  static const String videoEditor = '/spotlight/editor';
  static const String videoPreview = '/spotlight/preview';
  static const String videoAnalytics = '/spotlight/analytics';

  // المحادثات
  static const String chat = '/chat';
  static const String chatList = '/chat/list';
  static const String chatRoom = '/chat/room/';
  static const String whatsapp = '/chat/whatsapp';

  // المدفوعات
  static const String spotlightPayments = '/spotlight/payments';
  static const String spotlightPaymentMethods = '/spotlight/payments/methods';
  static const String spotlightBankTransfer = '/spotlight/payments/bank-transfer';
  static const String spotlightMadaPayment = '/spotlight/payments/mada';
  static const String spotlightPaymentConfirmation = '/spotlight/payments/confirmation';
  static const String spotlightPaymentHistory = '/spotlight/payments/history';

  // الإشعارات
  static const String notifications = '/notifications';
  static const String notificationSettings = '/notifications/settings';

  // الشركات
  static const String companies = '/companies';
  static const String companyDashboard = '/companies/dashboard';
  static const String companyProfile = '/companies/profile';
  static const String companyListings = '/companies/listings';
  static const String companyAnalytics = '/companies/analytics';

  // الاشتراكات
  static const String subscriptions = '/subscriptions';
  static const String subscriptionPlans = '/subscriptions/plans';
  static const String subscriptionDetails = '/subscriptions/details';
  static const String subscriptionHistory = '/subscriptions/history';

  // الوسائط
  static const String media = '/media';
  static const String vrView = '/media/vr-view';
  static const String panoramaView = '/media/panorama';
  static const String mediaUpload = '/media/upload';
  static const String camera = '/media/camera';

  // التحليلات
  static const String analytics = '/analytics';
  static const String analyticsDashboard = '/analytics/dashboard';
  static const String performanceMetrics = '/analytics/metrics';
  static const String userBehavior = '/analytics/behavior';

  // المواعيد
  static const String scheduling = '/scheduling';
  static const String calendar = '/scheduling/calendar';
  static const String scheduleVisit = '/scheduling/visit';
  static const String visitDetails = '/scheduling/details';
  static const String visitsHistory = '/scheduling/history';

  // الإعدادات
  static const String settings = '/settings';
  static const String language = '/settings/language';
  static const String privacy = '/settings/privacy';
  static const String help = '/settings/help';

  // الملف الشخصي
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String favorites = '/profile/favorites';
} 