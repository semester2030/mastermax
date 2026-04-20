import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../properties/models/property_model.dart';

/// حالات عقد الإيجار
enum RentalStatus {
  active('نشط'),
  expired('منتهي'),
  cancelled('ملغي'),
  renewed('مجدد');

  final String arabicName;
  const RentalStatus(this.arabicName);

  static RentalStatus fromString(String value) {
    return RentalStatus.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => RentalStatus.active,
    );
  }
}

/// Model لعقد الإيجار في نظام CRM للعقارات
///
/// يحتوي على معلومات عقد الإيجار
/// يربط مع Firestore Collection: `rentals`
class RentalModel {
  final String id;
  final String ownerId; // معرف المالك (شركة عقارية أو وسيط)
  final String propertyId; // معرف العقار المؤجر
  final String propertyTitle; // عنوان العقار (للرجوع السريع)
  final String customerId; // معرف العميل (المستأجر)
  final String customerName; // اسم العميل (للرجوع السريع)
  final RentalType rentalType; // نوع الإيجار (سكني/تجاري)
  final double monthlyRent; // الإيجار الشهري
  final DateTime startDate; // تاريخ بداية الإيجار
  final DateTime endDate; // تاريخ نهاية الإيجار
  final double deposit; // الضمان
  final bool includesUtilities; // يشمل المرافق
  final String? contractNumber; // رقم العقد
  final RentalStatus status; // حالة العقد
  final String? contractPdfUrl; // رابط ملف العقد (PDF)
  final String? notes; // ملاحظات
  final DateTime createdAt; // تاريخ الإنشاء
  final DateTime updatedAt; // تاريخ التحديث

  const RentalModel({
    required this.id,
    required this.ownerId,
    required this.propertyId,
    required this.propertyTitle,
    required this.customerId,
    required this.customerName,
    required this.rentalType,
    required this.monthlyRent,
    required this.startDate,
    required this.endDate,
    required this.deposit,
    required this.includesUtilities,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.contractNumber,
    this.contractPdfUrl,
    this.notes,
  });

  /// حساب مدة العقد بالأشهر
  int get contractDurationMonths {
    final difference = endDate.difference(startDate);
    return (difference.inDays / 30).ceil();
  }

  /// حساب إجمالي قيمة العقد
  double get totalContractValue {
    return monthlyRent * contractDurationMonths;
  }

  /// التحقق من انتهاء العقد
  bool get isExpired {
    return DateTime.now().isAfter(endDate);
  }

  /// التحقق من قرب انتهاء العقد (أقل من 30 يوم)
  bool get isNearExpiry {
    final daysUntilExpiry = endDate.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry > 0;
  }

  /// إنشاء RentalModel من Firestore DocumentSnapshot
  factory RentalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RentalModel.fromMap(data, doc.id);
  }

  /// إنشاء RentalModel من Map
  factory RentalModel.fromMap(Map<String, dynamic> map, String id) {
    return RentalModel(
      id: id,
      ownerId: map['ownerId'] ?? '',
      propertyId: map['propertyId'] ?? '',
      propertyTitle: map['propertyTitle'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      rentalType: map['rentalType'] != null
          ? RentalType.values.firstWhere(
              (e) => e.toString().split('.').last == map['rentalType'],
              orElse: () => RentalType.residential,
            )
          : RentalType.residential,
      monthlyRent: (map['monthlyRent'] ?? 0).toDouble(),
      startDate: map['startDate'] is Timestamp
          ? (map['startDate'] as Timestamp).toDate()
          : map['startDate'] is String
              ? DateTime.parse(map['startDate'] as String)
              : DateTime.now(),
      endDate: map['endDate'] is Timestamp
          ? (map['endDate'] as Timestamp).toDate()
          : map['endDate'] is String
              ? DateTime.parse(map['endDate'] as String)
              : DateTime.now(),
      deposit: (map['deposit'] ?? 0).toDouble(),
      includesUtilities: map['includesUtilities'] ?? false,
      contractNumber: map['contractNumber'],
      status: map['status'] != null
          ? RentalStatus.fromString(map['status'] as String)
          : RentalStatus.active,
      contractPdfUrl: map['contractPdfUrl'],
      notes: map['notes'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] is String
              ? DateTime.parse(map['createdAt'] as String)
              : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : map['updatedAt'] is String
              ? DateTime.parse(map['updatedAt'] as String)
              : DateTime.now(),
    );
  }

  /// تحويل RentalModel إلى Map للـ Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'customerId': customerId,
      'customerName': customerName,
      'rentalType': rentalType.toString().split('.').last,
      'monthlyRent': monthlyRent,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'deposit': deposit,
      'includesUtilities': includesUtilities,
      'contractNumber': contractNumber,
      'status': status.toString().split('.').last,
      'contractPdfUrl': contractPdfUrl,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// نسخ RentalModel مع تحديث بعض الحقول
  RentalModel copyWith({
    String? id,
    String? ownerId,
    String? propertyId,
    String? propertyTitle,
    String? customerId,
    String? customerName,
    RentalType? rentalType,
    double? monthlyRent,
    DateTime? startDate,
    DateTime? endDate,
    double? deposit,
    bool? includesUtilities,
    String? contractNumber,
    RentalStatus? status,
    String? contractPdfUrl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RentalModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      propertyTitle: propertyTitle ?? this.propertyTitle,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      rentalType: rentalType ?? this.rentalType,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      deposit: deposit ?? this.deposit,
      includesUtilities: includesUtilities ?? this.includesUtilities,
      contractNumber: contractNumber ?? this.contractNumber,
      status: status ?? this.status,
      contractPdfUrl: contractPdfUrl ?? this.contractPdfUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// إنشاء RentalModel فارغ
  factory RentalModel.empty() {
    final now = DateTime.now();
    return RentalModel(
      id: '',
      ownerId: '',
      propertyId: '',
      propertyTitle: '',
      customerId: '',
      customerName: '',
      rentalType: RentalType.residential,
      monthlyRent: 0,
      startDate: now,
      endDate: now.add(const Duration(days: 365)),
      deposit: 0,
      includesUtilities: false,
      status: RentalStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  }
}
