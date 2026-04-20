import 'package:cloud_firestore/cloud_firestore.dart';

/// Model للفرع في نظام إدارة الفروع
///
/// يحتوي على معلومات الفرع الأساسية
/// يربط مع Firestore Collection: `branches`
class BranchModel {
  final String id;
  final String companyId; // معرف الشركة
  final String name; // اسم الفرع
  final String address; // عنوان الفرع
  final String phone; // رقم هاتف الفرع
  final String? email; // البريد الإلكتروني (اختياري)
  final String? managerName; // اسم المدير (اختياري)
  final String? managerPhone; // رقم هاتف المدير (اختياري)
  final bool isActive; // حالة الفرع (نشط/غير نشط)
  final DateTime createdAt; // تاريخ الإنشاء
  final DateTime updatedAt; // تاريخ التحديث

  const BranchModel({
    required this.id,
    required this.companyId,
    required this.name,
    required this.address,
    required this.phone,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.managerName,
    this.managerPhone,
  });

  /// إنشاء BranchModel من Firestore DocumentSnapshot
  factory BranchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BranchModel.fromMap(data, doc.id);
  }

  /// إنشاء BranchModel من Map
  factory BranchModel.fromMap(Map<String, dynamic> map, String id) {
    return BranchModel(
      id: id,
      companyId: map['companyId'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      managerName: map['managerName'],
      managerPhone: map['managerPhone'],
      isActive: map['isActive'] ?? true,
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

  /// تحويل BranchModel إلى Map للـ Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'managerName': managerName,
      'managerPhone': managerPhone,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// نسخ BranchModel مع تحديث بعض الحقول
  BranchModel copyWith({
    String? id,
    String? companyId,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? managerName,
    String? managerPhone,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BranchModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      managerName: managerName ?? this.managerName,
      managerPhone: managerPhone ?? this.managerPhone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// إنشاء BranchModel فارغ
  factory BranchModel.empty() {
    final now = DateTime.now();
    return BranchModel(
      id: '',
      companyId: '',
      name: '',
      address: '',
      phone: '',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }
}
