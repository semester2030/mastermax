import 'package:cloud_firestore/cloud_firestore.dart';

/// Model لعملية البيع في نظام CRM لمعرض السيارات
///
/// يحتوي على معلومات عملية البيع
/// يربط مع Firestore Collection: `sales`
class SaleModel {
  final String id;
  final String sellerId; // معرف البائع (معرض السيارات)
  final String carId; // معرف السيارة المباعة
  final String carTitle; // عنوان السيارة (للرجوع السريع)
  final String customerId; // معرف العميل
  final String customerName; // اسم العميل (للرجوع السريع)
  final double salePrice; // سعر البيع
  final double? profit; // الربح (اختياري)
  final String? paymentMethod; // طريقة الدفع (نقدي/تحويل/تقسيط)
  final String? notes; // ملاحظات (اختياري)
  final DateTime saleDate; // تاريخ البيع
  final DateTime createdAt; // تاريخ الإنشاء
  final DateTime updatedAt; // تاريخ التحديث

  const SaleModel({
    required this.id,
    required this.sellerId,
    required this.carId,
    required this.carTitle,
    required this.customerId,
    required this.customerName,
    required this.salePrice,
    required this.saleDate,
    required this.createdAt,
    required this.updatedAt,
    this.profit,
    this.paymentMethod,
    this.notes,
  });

  /// إنشاء SaleModel من Firestore DocumentSnapshot
  factory SaleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SaleModel.fromMap(data, doc.id);
  }

  /// إنشاء SaleModel من Map
  factory SaleModel.fromMap(Map<String, dynamic> map, String id) {
    return SaleModel(
      id: id,
      sellerId: map['sellerId'] ?? '',
      carId: map['carId'] ?? '',
      carTitle: map['carTitle'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      salePrice: (map['salePrice'] ?? 0).toDouble(),
      profit: map['profit'] != null ? (map['profit'] as num).toDouble() : null,
      paymentMethod: map['paymentMethod'],
      notes: map['notes'],
      saleDate: map['saleDate'] is Timestamp
          ? (map['saleDate'] as Timestamp).toDate()
          : map['saleDate'] is String
              ? DateTime.parse(map['saleDate'] as String)
              : DateTime.now(),
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

  /// تحويل SaleModel إلى Map للـ Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'sellerId': sellerId,
      'carId': carId,
      'carTitle': carTitle,
      'customerId': customerId,
      'customerName': customerName,
      'salePrice': salePrice,
      'profit': profit,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'saleDate': Timestamp.fromDate(saleDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// نسخ SaleModel مع تحديث بعض الحقول
  SaleModel copyWith({
    String? id,
    String? sellerId,
    String? carId,
    String? carTitle,
    String? customerId,
    String? customerName,
    double? salePrice,
    double? profit,
    String? paymentMethod,
    String? notes,
    DateTime? saleDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SaleModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      carId: carId ?? this.carId,
      carTitle: carTitle ?? this.carTitle,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      salePrice: salePrice ?? this.salePrice,
      profit: profit ?? this.profit,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      saleDate: saleDate ?? this.saleDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// إنشاء SaleModel فارغ
  factory SaleModel.empty() {
    final now = DateTime.now();
    return SaleModel(
      id: '',
      sellerId: '',
      carId: '',
      carTitle: '',
      customerId: '',
      customerName: '',
      salePrice: 0,
      saleDate: now,
      createdAt: now,
      updatedAt: now,
    );
  }
}
