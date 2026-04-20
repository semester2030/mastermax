import 'package:cloud_firestore/cloud_firestore.dart';
import '../../spotlight/models/video_model.dart';

class CarModel {
  final String id;
  final String title;           // عنوان الإعلان
  final String description;     // وصف السيارة
  final String brand;          // الماركة
  final String model;          // موديل السيارة
  final int year;             // سنة الصنع
  final double price;         // السعر (سعر البيع المعروض)
  final double? purchasePrice; // ✅ سعر الشراء/التكلفة (لحساب الربح في CRM - للسيارات الجاهزة: سعر الشراء، للسيارات المجمعة: التكلفة)
  final String sellerId;      // معرف البائع
  final String sellerName;    // اسم البائع
  final String sellerPhone;   // رقم البائع
  final List<String> images;  // الصور
  final String mainImage;     // الصورة الرئيسية
  final bool hasVideo;        // هل يوجد فيديو
  final String? videoUrl;     // رابط الفيديو (اختياري)
  final List<VideoModel>? videos; // قائمة الفيديوهات
  final GeoPoint? location;    // الموقع (اختياري)
  final String address;       // العنوان
  final String condition;     // حالة السيارة (جديد/مستعمل)
  final int kilometers;       // عدد الكيلومترات
  final String transmission; // نوع القير (أوتوماتيك/عادي)
  final String fuelType;     // نوع الوقود
  final List<String> features; // المميزات
  final DateTime createdAt;   // تاريخ الإنشاء
  final DateTime updatedAt;   // تاريخ التحديث
  final bool isActive;       // نشط
  final bool isFeatured;     // مميز
  final bool isVerified;     // موثق
  final bool has360View;     // يدعم عرض 360
  final String? panoramaUrl; // رابط صورة 360
  final String? virtualTourUrl; // رابط الجولة الافتراضية
  final bool hasInteriorView; // يدعم عرض المقصورة الداخلية
  final String? interiorPanoramaUrl; // رابط صورة المقصورة الداخلية 360

  const CarModel({
    required this.id,
    required this.title,
    required this.description,
    required this.brand,
    required this.model,
    required this.year,
    required this.price,
    this.purchasePrice, // ✅ سعر الشراء/التكلفة (اختياري)
    required this.sellerId,
    required this.sellerName,
    required this.sellerPhone,
    required this.images,
    required this.mainImage,
    required this.hasVideo,
    required this.address,
    required this.condition,
    required this.kilometers,
    required this.transmission,
    required this.fuelType,
    required this.features,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.isFeatured,
    required this.isVerified,
    this.videoUrl,
    this.videos,
    this.location,
    this.has360View = false,
    this.panoramaUrl,
    this.virtualTourUrl,
    this.hasInteriorView = false,
    this.interiorPanoramaUrl,
  });

  factory CarModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    return CarModel.fromMap(json, id);
  }

  factory CarModel.fromMap(Map<String, dynamic> map, String id) {
    final locationData = map['location'];
    final GeoPoint? location = locationData is GeoPoint ? locationData : null;

    return CarModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      brand: map['brand'] ?? '',
      model: map['model'] ?? '',
      year: map['year'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      purchasePrice: map['purchasePrice'] != null ? (map['purchasePrice'] as num).toDouble() : null,
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      sellerPhone: map['sellerPhone'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      mainImage: map['mainImage'] ?? '',
      hasVideo: map['hasVideo'] ?? false,
      videoUrl: map['videoUrl'],
      videos: (map['videos'] as List<dynamic>?)?.map((video) => VideoModel.fromMap(video)).toList(),
      location: location,
      address: map['address'] ?? '',
      condition: map['condition'] ?? '',
      kilometers: map['kilometers'] ?? 0,
      transmission: map['transmission'] ?? '',
      fuelType: map['fuelType'] ?? '',
      features: List<String>.from(map['features'] ?? []),
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
      isActive: map['isActive'] ?? true,
      isFeatured: map['isFeatured'] ?? false,
      isVerified: map['isVerified'] ?? false,
      has360View: map['has360View'] ?? false,
      panoramaUrl: map['panoramaUrl'],
      virtualTourUrl: map['virtualTourUrl'],
      hasInteriorView: map['hasInteriorView'] ?? false,
      interiorPanoramaUrl: map['interiorPanoramaUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'brand': brand,
      'model': model,
      'year': year,
      'price': price,
      'purchasePrice': purchasePrice, // ⚠️ حساس - لا يعرض للعامة (CRM فقط)
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerPhone': sellerPhone,
      'images': images,
      'mainImage': mainImage,
      'hasVideo': hasVideo,
      'videoUrl': videoUrl,
      'videos': videos?.map((video) => video.toMap()).toList(),
      'location': location,
      'address': address,
      'condition': condition,
      'kilometers': kilometers,
      'transmission': transmission,
      'fuelType': fuelType,
      'features': features,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'isFeatured': isFeatured,
      'isVerified': isVerified,
      'has360View': has360View,
      'panoramaUrl': panoramaUrl,
      'virtualTourUrl': virtualTourUrl,
      'hasInteriorView': hasInteriorView,
      'interiorPanoramaUrl': interiorPanoramaUrl,
    };
  }

  CarModel copyWith({
    String? id,
    String? title,
    String? description,
    String? brand,
    String? model,
    int? year,
    double? price,
    double? purchasePrice,
    String? sellerId,
    String? sellerName,
    String? sellerPhone,
    List<String>? images,
    String? mainImage,
    bool? hasVideo,
    String? videoUrl,
    List<VideoModel>? videos,
    GeoPoint? location,
    String? address,
    String? condition,
    int? kilometers,
    String? transmission,
    String? fuelType,
    List<String>? features,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? isFeatured,
    bool? isVerified,
    bool? has360View,
    String? panoramaUrl,
    String? virtualTourUrl,
    bool? hasInteriorView,
    String? interiorPanoramaUrl,
  }) {
    return CarModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      price: price ?? this.price,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerPhone: sellerPhone ?? this.sellerPhone,
      images: images ?? this.images,
      mainImage: mainImage ?? this.mainImage,
      hasVideo: hasVideo ?? this.hasVideo,
      videoUrl: videoUrl ?? this.videoUrl,
      videos: videos ?? this.videos,
      location: location ?? this.location,
      address: address ?? this.address,
      condition: condition ?? this.condition,
      kilometers: kilometers ?? this.kilometers,
      transmission: transmission ?? this.transmission,
      fuelType: fuelType ?? this.fuelType,
      features: features ?? this.features,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      isVerified: isVerified ?? this.isVerified,
      has360View: has360View ?? this.has360View,
      panoramaUrl: panoramaUrl ?? this.panoramaUrl,
      virtualTourUrl: virtualTourUrl ?? this.virtualTourUrl,
      hasInteriorView: hasInteriorView ?? this.hasInteriorView,
      interiorPanoramaUrl: interiorPanoramaUrl ?? this.interiorPanoramaUrl,
    );
  }

  // إنشاء نموذج سيارة فارغ
  factory CarModel.empty() {
    return CarModel(
      id: '',
      title: '',
      description: '',
      brand: '',
      model: '',
      year: 0,
      price: 0,
      purchasePrice: null,
      sellerId: '',
      sellerName: '',
      sellerPhone: '',
      images: [],
      mainImage: '',
      hasVideo: false,
      address: '',
      condition: '',
      kilometers: 0,
      transmission: '',
      fuelType: '',
      features: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: false,
      isFeatured: false,
      isVerified: false,
    );
  }
}
