import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String agentId; // معرف الوسيط
  final String customerId; // معرف العميل
  final String customerName; // اسم العميل
  final String propertyId; // معرف العقار
  final String propertyTitle; // عنوان العقار
  final DateTime appointmentDate; // تاريخ الموعد
  final String status; // الحالة: pending, confirmed, completed, cancelled
  final String? notes; // ملاحظات
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppointmentModel({
    required this.id,
    required this.agentId,
    required this.customerId,
    required this.customerName,
    required this.propertyId,
    required this.propertyTitle,
    required this.appointmentDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppointmentModel.fromMap(data, doc.id);
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String id) {
    return AppointmentModel(
      id: id,
      agentId: map['agentId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      propertyId: map['propertyId'] ?? '',
      propertyTitle: map['propertyTitle'] ?? '',
      appointmentDate: map['appointmentDate'] is Timestamp ? (map['appointmentDate'] as Timestamp).toDate() : map['appointmentDate'] is String ? DateTime.parse(map['appointmentDate'] as String) : DateTime.now(),
      status: map['status'] ?? 'pending',
      notes: map['notes'],
      createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : map['createdAt'] is String ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : map['updatedAt'] is String ? DateTime.parse(map['updatedAt'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'agentId': agentId,
      'customerId': customerId,
      'customerName': customerName,
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AppointmentModel copyWith({String? id, String? agentId, String? customerId, String? customerName, String? propertyId, String? propertyTitle, DateTime? appointmentDate, String? status, String? notes, DateTime? createdAt, DateTime? updatedAt}) {
    return AppointmentModel(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      propertyId: propertyId ?? this.propertyId,
      propertyTitle: propertyTitle ?? this.propertyTitle,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AppointmentModel.empty() {
    final now = DateTime.now();
    return AppointmentModel(id: '', agentId: '', customerId: '', customerName: '', propertyId: '', propertyTitle: '', appointmentDate: now, status: 'pending', createdAt: now, updatedAt: now);
  }
}
