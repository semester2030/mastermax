import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryModel {
  final String id;
  final String companyId;
  final String propertyId; // معرف العقار
  final String propertyTitle; // عنوان العقار
  final String status; // الحالة: available, reserved, sold
  final DateTime createdAt;
  final DateTime updatedAt;

  const InventoryModel({
    required this.id,
    required this.companyId,
    required this.propertyId,
    required this.propertyTitle,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InventoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryModel.fromMap(data, doc.id);
  }

  factory InventoryModel.fromMap(Map<String, dynamic> map, String id) {
    return InventoryModel(
      id: id,
      companyId: map['companyId'] ?? '',
      propertyId: map['propertyId'] ?? '',
      propertyTitle: map['propertyTitle'] ?? '',
      status: map['status'] ?? 'available',
      createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : map['createdAt'] is String ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : map['updatedAt'] is String ? DateTime.parse(map['updatedAt'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  InventoryModel copyWith({String? id, String? companyId, String? propertyId, String? propertyTitle, String? status, DateTime? createdAt, DateTime? updatedAt}) {
    return InventoryModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      propertyId: propertyId ?? this.propertyId,
      propertyTitle: propertyTitle ?? this.propertyTitle,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory InventoryModel.empty() {
    final now = DateTime.now();
    return InventoryModel(id: '', companyId: '', propertyId: '', propertyTitle: '', status: 'available', createdAt: now, updatedAt: now);
  }
}
