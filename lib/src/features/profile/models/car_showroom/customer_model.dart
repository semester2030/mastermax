import 'package:cloud_firestore/cloud_firestore.dart';

/// Model للعميل في نظام CRM لمعرض السيارات
///
/// يحتوي على معلومات العميل الأساسية
/// يربط مع Firestore Collection: `customers`
class CustomerModel {
  final String id;
  final String sellerId; // معرف البائع (معرض السيارات)
  final String name; // اسم العميل
  final String phone; // رقم الجوال
  final String? email; // البريد الإلكتروني (اختياري)
  final String? address; // العنوان (اختياري)
  final String? notes; // ملاحظات (اختياري)
  final DateTime createdAt; // تاريخ الإنشاء
  final DateTime updatedAt; // تاريخ التحديث

  const CustomerModel({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.phone,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.address,
    this.notes,
  });

  /// إنشاء CustomerModel من Firestore DocumentSnapshot
  factory CustomerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CustomerModel.fromMap(data, doc.id);
  }

  /// إنشاء CustomerModel من Map
  factory CustomerModel.fromMap(Map<String, dynamic> map, String id) {
    return CustomerModel(
      id: id,
      sellerId: map['sellerId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      address: map['address'],
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

  /// تحويل CustomerModel إلى Map للـ Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'sellerId': sellerId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// نسخ CustomerModel مع تحديث بعض الحقول
  CustomerModel copyWith({
    String? id,
    String? sellerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// إنشاء CustomerModel فارغ
  factory CustomerModel.empty() {
    final now = DateTime.now();
    return CustomerModel(
      id: '',
      sellerId: '',
      name: '',
      phone: '',
      createdAt: now,
      updatedAt: now,
    );
  }
}
