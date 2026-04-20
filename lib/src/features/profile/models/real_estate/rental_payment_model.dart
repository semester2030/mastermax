import 'package:cloud_firestore/cloud_firestore.dart';

/// حالات الدفعة
enum PaymentStatus {
  paid('مدفوع'),
  overdue('متأخر'),
  due('مستحق'),
  pending('قيد الانتظار');

  final String arabicName;
  const PaymentStatus(this.arabicName);

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}

/// Model لدفعة الإيجار في نظام CRM للعقارات
///
/// يحتوي على معلومات دفعة الإيجار
/// يربط مع Firestore Collection: `rental_payments`
class RentalPaymentModel {
  final String id;
  final String rentalId; // معرف عقد الإيجار
  final double amount; // مبلغ الدفعة
  final DateTime dueDate; // تاريخ الاستحقاق
  final DateTime? paidDate; // تاريخ الدفع الفعلي
  final PaymentStatus status; // حالة الدفعة
  final String? receiptNumber; // رقم الإيصال
  final String? notes; // ملاحظات
  final DateTime createdAt; // تاريخ الإنشاء
  final DateTime updatedAt; // تاريخ التحديث

  const RentalPaymentModel({
    required this.id,
    required this.rentalId,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.paidDate,
    this.receiptNumber,
    this.notes,
  });

  /// التحقق من تأخر الدفعة
  bool get isOverdue {
    return status == PaymentStatus.overdue ||
        (status == PaymentStatus.due && DateTime.now().isAfter(dueDate));
  }

  /// التحقق من استحقاق الدفعة (قبل 7 أيام من الاستحقاق)
  bool get isDueSoon {
    final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
    return daysUntilDue <= 7 && daysUntilDue >= 0 && status == PaymentStatus.pending;
  }

  /// إنشاء RentalPaymentModel من Firestore DocumentSnapshot
  factory RentalPaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RentalPaymentModel.fromMap(data, doc.id);
  }

  /// إنشاء RentalPaymentModel من Map
  factory RentalPaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return RentalPaymentModel(
      id: id,
      rentalId: map['rentalId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      dueDate: map['dueDate'] is Timestamp
          ? (map['dueDate'] as Timestamp).toDate()
          : map['dueDate'] is String
              ? DateTime.parse(map['dueDate'] as String)
              : DateTime.now(),
      paidDate: map['paidDate'] != null
          ? (map['paidDate'] is Timestamp
              ? (map['paidDate'] as Timestamp).toDate()
              : map['paidDate'] is String
                  ? DateTime.parse(map['paidDate'] as String)
                  : null)
          : null,
      status: map['status'] != null
          ? PaymentStatus.fromString(map['status'] as String)
          : PaymentStatus.pending,
      receiptNumber: map['receiptNumber'],
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

  /// تحويل RentalPaymentModel إلى Map للـ Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'rentalId': rentalId,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      'status': status.toString().split('.').last,
      'receiptNumber': receiptNumber,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// نسخ RentalPaymentModel مع تحديث بعض الحقول
  RentalPaymentModel copyWith({
    String? id,
    String? rentalId,
    double? amount,
    DateTime? dueDate,
    DateTime? paidDate,
    PaymentStatus? status,
    String? receiptNumber,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RentalPaymentModel(
      id: id ?? this.id,
      rentalId: rentalId ?? this.rentalId,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      status: status ?? this.status,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// إنشاء RentalPaymentModel فارغ
  factory RentalPaymentModel.empty() {
    final now = DateTime.now();
    return RentalPaymentModel(
      id: '',
      rentalId: '',
      amount: 0,
      dueDate: now,
      status: PaymentStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
  }
}
