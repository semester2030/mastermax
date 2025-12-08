import 'package:cloud_firestore/cloud_firestore.dart';

enum VideoType {
  car,
  realEstate
}

class VideoModel {
  final String id;
  final String url;
  final String thumbnail;
  final String title;
  final String description;
  final VideoType type;
  
  // معلومات السيارات
  final String? carId;
  final String? carBrand;
  final String? carModel;
  final String? carYear;
  
  // معلومات العقارات
  final String? realEstateId;
  final String? realEstateType;
  final String? realEstateLocation;
  
  // معلومات البائع
  final String? sellerId;
  final String? sellerName;
  final String? sellerPhone;
  final double? price;
  
  // معلومات عامة
  final DateTime createdAt;
  final int viewsCount;
  final int likesCount;
  final bool isFeatured;
  final GeoPoint location;
  final String address;

  VideoModel({
    required this.id,
    required this.url,
    required this.thumbnail,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt, required this.location, required this.address, this.carId,
    this.carBrand,
    this.carModel,
    this.carYear,
    this.realEstateId,
    this.realEstateType,
    this.realEstateLocation,
    this.sellerId = '',
    this.sellerName,
    this.sellerPhone,
    this.price,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.isFeatured = false,
  });

  factory VideoModel.fromMap(Map<String, dynamic> map) {
    return VideoModel(
      id: map['id'] ?? '',
      url: map['url'] ?? '',
      thumbnail: map['thumbnail'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: _parseVideoType(map['type']),
      carId: map['carId'],
      carBrand: map['carBrand'],
      carModel: map['carModel'],
      carYear: map['carYear'],
      realEstateId: map['realEstateId'],
      realEstateType: map['realEstateType'],
      realEstateLocation: map['realEstateLocation'],
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'],
      sellerPhone: map['sellerPhone'],
      price: (map['price'] as num?)?.toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      viewsCount: map['viewsCount'] ?? 0,
      likesCount: map['likesCount'] ?? 0,
      isFeatured: map['isFeatured'] ?? false,
      location: map['location'] ?? const GeoPoint(0, 0),
      address: map['address'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'thumbnail': thumbnail,
      'title': title,
      'description': description,
      'type': type == VideoType.car ? 'car' : 'realEstate',
      'carId': carId,
      'carBrand': carBrand,
      'carModel': carModel,
      'carYear': carYear,
      'realEstateId': realEstateId,
      'realEstateType': realEstateType,
      'realEstateLocation': realEstateLocation,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerPhone': sellerPhone,
      'price': price,
      'createdAt': Timestamp.fromDate(createdAt),
      'viewsCount': viewsCount,
      'likesCount': likesCount,
      'isFeatured': isFeatured,
      'location': location,
      'address': address,
    };
  }

  VideoModel copyWith({
    String? id,
    String? url,
    String? thumbnail,
    String? title,
    String? description,
    VideoType? type,
    String? carId,
    String? carBrand,
    String? carModel,
    String? carYear,
    String? realEstateId,
    String? realEstateType,
    String? realEstateLocation,
    String? sellerId,
    String? sellerName,
    String? sellerPhone,
    double? price,
    DateTime? createdAt,
    int? viewsCount,
    int? likesCount,
    bool? isFeatured,
    GeoPoint? location,
    String? address,
  }) {
    return VideoModel(
      id: id ?? this.id,
      url: url ?? this.url,
      thumbnail: thumbnail ?? this.thumbnail,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      carId: carId ?? this.carId,
      carBrand: carBrand ?? this.carBrand,
      carModel: carModel ?? this.carModel,
      carYear: carYear ?? this.carYear,
      realEstateId: realEstateId ?? this.realEstateId,
      realEstateType: realEstateType ?? this.realEstateType,
      realEstateLocation: realEstateLocation ?? this.realEstateLocation,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerPhone: sellerPhone ?? this.sellerPhone,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      viewsCount: viewsCount ?? this.viewsCount,
      likesCount: likesCount ?? this.likesCount,
      isFeatured: isFeatured ?? this.isFeatured,
      location: location ?? this.location,
      address: address ?? this.address,
    );
  }

  static VideoType _parseVideoType(String? type) {
    if (type == null) return VideoType.car;
    switch (type.toLowerCase()) {
      case 'car':
        return VideoType.car;
      case 'realestate':
      case 'real_estate':
      case 'real estate':
        return VideoType.realEstate;
      default:
        return VideoType.car;
    }
  }
} 