import 'package:cloud_firestore/cloud_firestore.dart';

class UserFeatures {
  final String userId;
  final UserType userType;
  final List<String> features;
  final Map<String, dynamic> extraFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserFeatures({
    required this.userId,
    required this.userType,
    required this.features,
    required this.extraFields,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserFeatures.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserFeatures(
      userId: doc.id,
      userType: UserType.values.firstWhere(
        (e) => e.toString() == data['userType'],
        orElse: () => UserType.individual,
      ),
      features: List<String>.from(data['features'] ?? []),
      extraFields: Map<String, dynamic>.from(data['extraFields'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userType': userType.toString(),
      'features': features,
      'extraFields': extraFields,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserFeatures copyWith({
    String? userId,
    UserType? userType,
    List<String>? features,
    Map<String, dynamic>? extraFields,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserFeatures(
      userId: userId ?? this.userId,
      userType: userType ?? this.userType,
      features: features ?? this.features,
      extraFields: extraFields ?? this.extraFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum UserType {
  individual,         // مستخدم فردي
  realEstateCompany,  // شركة عقارية
  carDealer,         // معرض سيارات
  realEstateAgent,   // وسيط عقاري
  carTrader,         // تاجر سيارات
}

/// المميزات حسب نوع المستخدم
class UserTypeFeatures {
  // المميزات الأساسية للمستخدم الفردي
  static const List<String> individualFeatures = [
    'المفضلة',           // حفظ العناصر المفضلة
    'البحث',            // البحث عن عقارات/سيارات
    'مشاهدة الإعلانات', // عرض الإعلانات المتاحة
    'التواصل المباشر',  // التواصل مع المعلنين
  ];

  // المميزات الأساسية للشركات العقارية
  static const List<String> realEstateBusinessFeatures = [
    'إدارة العقارات',
    'إدارة المبيعات',
    'إدارة الفريق',
    'التقارير والإحصائيات',
    'الإعلانات المميزة',
    'خدمة العملاء',
    'التسويق الرقمي',
    'جدولة المعاينات',
    'التقييم العقاري',
  ];

  // المميزات الأساسية لمعارض السيارات
  static const List<String> carDealerFeatures = [
    'إدارة المركبات',
    'إدارة المبيعات',
    'إدارة الفريق',
    'التقارير والإحصائيات',
    'الإعلانات المميزة',
    'خدمة العملاء',
    'التسويق الرقمي',
    'خدمة ما بعد البيع',
    'الضمان والصيانة',
    'العروض الخاصة',
    'التمويل والتقسيط',
  ];

  // مميزات الوسيط العقاري
  static const List<String> realEstateAgentFeatures = [
    'إدارة العقارات',
    'إدارة المبيعات',
    'جدولة المعاينات',
    'متابعة العملاء',
    'العمولات والمدفوعات',
    'التقييم العقاري',
  ];

  // مميزات تاجر السيارات
  static const List<String> carTraderFeatures = [
    'إدارة المركبات',
    'إدارة المبيعات',
    'إدارة المخزون',
    'طلبات الشراء',
    'المزادات',
    'الشحن والتوصيل',
    'خدمات الفحص',
    'خدمة ما بعد البيع',
    'الضمان والصيانة',
  ];

  // تعيين المميزات لكل نوع مستخدم
  static const Map<UserType, List<String>> features = {
    UserType.individual: individualFeatures,
    UserType.realEstateCompany: realEstateBusinessFeatures,
    UserType.carDealer: carDealerFeatures,
    UserType.realEstateAgent: realEstateAgentFeatures,
    UserType.carTrader: carTraderFeatures,
  };

  // الحصول على مميزات نوع مستخدم معين
  static List<String> getFeatures(UserType type) {
    return features[type] ?? [];
  }

  // التحقق من وجود ميزة معينة لنوع مستخدم
  static bool hasFeature(UserType type, String feature) {
    final userFeatures = getFeatures(type);
    return userFeatures.contains(feature);
  }
} 