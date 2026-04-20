import 'package:cloud_firestore/cloud_firestore.dart';

/// Model للعميل في نظام CRM للعقارات
///
/// يحتوي على معلومات العميل الأساسية
/// يربط مع Firestore Collection: `real_estate_customers`
class RealEstateCustomerModel {
  final String id;
  final String companyId; // معرف الشركة/الوسيط
  final String name; // اسم العميل
  final String phone; // رقم الجوال
  final String? email; // البريد الإلكتروني (اختياري)
  final String? address; // العنوان (اختياري)
  final String? notes; // ملاحظات (اختياري)
  final List<String> interestedProperties; // قائمة العقارات المهتم بها
  final DateTime createdAt; // تاريخ الإنشاء
  final DateTime updatedAt; // تاريخ التحديث

  const RealEstateCustomerModel({
    required this.id,
    required this.companyId,
    required this.name,
    required this.phone,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.address,
    this.notes,
    this.interestedProperties = const [],
  });

  /// إنشاء RealEstateCustomerModel من Firestore DocumentSnapshot
  factory RealEstateCustomerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RealEstateCustomerModel.fromMap(data, doc.id);
  }

  /// إنشاء RealEstateCustomerModel من Map
  factory RealEstateCustomerModel.fromMap(Map<String, dynamic> map, String id) {
    return RealEstateCustomerModel(
      id: id,
      companyId: map['companyId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      address: map['address'],
      notes: map['notes'],
      interestedProperties: map['interestedProperties'] != null
          ? List<String>.from(map['interestedProperties'])
          : [],
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

  /// تحويل RealEstateCustomerModel إلى Map للـ Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'interestedProperties': interestedProperties,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// نسخ RealEstateCustomerModel مع تحديث بعض الحقول
  RealEstateCustomerModel copyWith({
    String? id,
    String? companyId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    List<String>? interestedProperties,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RealEstateCustomerModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      interestedProperties: interestedProperties ?? this.interestedProperties,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// إنشاء RealEstateCustomerModel فارغ
  factory RealEstateCustomerModel.empty() {
    final now = DateTime.now();
    return RealEstateCustomerModel(
      id: '',
      companyId: '',
      name: '',
      phone: '',
      createdAt: now,
      updatedAt: now,
    );
  }
}
