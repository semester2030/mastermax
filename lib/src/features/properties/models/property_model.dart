import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property_type.dart';
import 'property_room_details.dart';
import '../../../core/utils/logger.dart';

/// حالات العقار المختلفة
enum PropertyStatus {
  /// العقار متاح
  available('متاح'),
  /// العقار مباع
  sold('مباع'),
  /// العقار مؤجر
  rented('مؤجر'),
  /// العقار تحت التعاقد
  underContract('تحت التعاقد'),
  /// العقار معلق
  suspended('معلق');

  final String arabicName;
  const PropertyStatus(this.arabicName);
}

/// أنواع العروض
enum OfferType {
  /// عرض للبيع
  sale('للبيع'),
  /// عرض للإيجار
  rent('للإيجار');

  final String arabicName;
  const OfferType(this.arabicName);
}

/// أنواع الإيجار
enum RentalType {
  /// إيجار سكني (شقة، فيلا)
  residential('إيجار سكني'),
  /// إيجار تجاري (محل، معرض، مكتب)
  commercial('إيجار تجاري');

  final String arabicName;
  const RentalType(this.arabicName);
}

/// نموذج بيانات العقار
class PropertyModel {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final double price; // سعر البيع/الإيجار المعروض
  final double? purchasePrice; // ✅ سعر الشراء/التكلفة (لحساب الربح في CRM - للعقارات الجاهزة: سعر الشراء، للعقارات المنفذة: التكلفة)
  final List<String> images;
  final String? panoramaUrl;
  final String? virtualTourUrl;
  final bool has360View;
  final String address;
  final LatLng location;
  final PropertyType type;
  final PropertyStatus status;
  final OfferType offerType;
  
  // معلومات أساسية
  final int rooms;
  final int bathrooms;
  final double area;
  final int floors;
  final int yearBuilt;
  
  // ✅ تفاصيل الغرف والمساحات (جديد)
  final PropertyRoomDetails? roomDetails;
  
  // ✅ تفاصيل مهمة للعقارات في المملكة (جديد)
  final bool hasApartments; // هل الفيلا فيها شقق
  final bool hasInternalStairs; // درج داخلي
  final bool hasExternalStairs; // درج خارجي
  final String? propertyDirection; // اتجاه العقار (شرقي، غربي، شمالي، جنوبي)
  final String? streetWidth; // عرض الشارع
  final int? livingRoomsCount; // عدد المجالس
  final int? majlisCount; // عدد المجالس (رجال/نساء)
  
  // مميزات إضافية
  final Map<String, bool> features;
  final List<String> amenities;
  
  // معلومات العرض
  final bool isNegotiable;
  final double? monthlyRent;
  final bool? includesUtilities;
  final int? minimumRentPeriod;
  
  // معلومات المعاينة
  final List<DateTime> availableViewings;
  final bool requiresAppointment;
  
  // التقييمات والتعليقات
  final double rating;
  final List<PropertyReview> reviews;
  
  // توقيتات
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastViewed;
  final String contactPhone;

  /// إنشاء نموذج عقار جديد
  PropertyModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.price,
    this.purchasePrice, // ✅ سعر الشراء/التكلفة (اختياري)
    required this.images,
    required this.address,
    required this.location,
    required this.type,
    required this.status,
    required this.offerType,
    required this.rooms,
    required this.bathrooms,
    required this.area,
    required this.createdAt,
    required this.updatedAt,
    required this.contactPhone,
    this.panoramaUrl,
    this.virtualTourUrl,
    this.has360View = false,
    this.floors = 1,
    this.yearBuilt = 0,
    this.roomDetails,
    this.hasApartments = false,
    this.hasInternalStairs = false,
    this.hasExternalStairs = false,
    this.propertyDirection,
    this.streetWidth,
    this.livingRoomsCount,
    this.majlisCount,
    this.features = const {},
    this.amenities = const [],
    this.isNegotiable = false,
    this.monthlyRent,
    this.includesUtilities,
    this.minimumRentPeriod,
    this.availableViewings = const [],
    this.requiresAppointment = true,
    this.rating = 0.0,
    this.reviews = const [],
    this.lastViewed,
  });

  /// إنشاء نموذج عقار فارغ
  factory PropertyModel.empty() {
    return PropertyModel(
      id: '',
      ownerId: '',
      title: '',
      description: '',
      price: 0,
      purchasePrice: null,
      images: [],
      address: '',
      location: const LatLng(0, 0),
      type: PropertyType.other,
      status: PropertyStatus.available,
      offerType: OfferType.sale,
      rooms: 0,
      bathrooms: 0,
      area: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      contactPhone: '',
    );
  }

  /// إنشاء نسخة معدلة من العقار
  PropertyModel copyWith({
    String? id,
    String? ownerId,
    double? purchasePrice,
    String? title,
    String? description,
    double? price,
    List<String>? images,
    String? panoramaUrl,
    String? virtualTourUrl,
    bool? has360View,
    String? address,
    LatLng? location,
    PropertyType? type,
    PropertyStatus? status,
    OfferType? offerType,
    int? rooms,
    int? bathrooms,
    double? area,
    int? floors,
    int? yearBuilt,
    PropertyRoomDetails? roomDetails,
    bool? hasApartments,
    bool? hasInternalStairs,
    bool? hasExternalStairs,
    String? propertyDirection,
    String? streetWidth,
    int? livingRoomsCount,
    int? majlisCount,
    Map<String, bool>? features,
    List<String>? amenities,
    bool? isNegotiable,
    double? monthlyRent,
    bool? includesUtilities,
    int? minimumRentPeriod,
    List<DateTime>? availableViewings,
    bool? requiresAppointment,
    double? rating,
    List<PropertyReview>? reviews,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastViewed,
  }) {
    return PropertyModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      images: images ?? this.images,
      panoramaUrl: panoramaUrl ?? this.panoramaUrl,
      virtualTourUrl: virtualTourUrl ?? this.virtualTourUrl,
      has360View: has360View ?? this.has360View,
      address: address ?? this.address,
      location: location ?? this.location,
      type: type ?? this.type,
      status: status ?? this.status,
      offerType: offerType ?? this.offerType,
      rooms: rooms ?? this.rooms,
      bathrooms: bathrooms ?? this.bathrooms,
      area: area ?? this.area,
      floors: floors ?? this.floors,
      yearBuilt: yearBuilt ?? this.yearBuilt,
      roomDetails: roomDetails ?? this.roomDetails,
      hasApartments: hasApartments ?? this.hasApartments,
      hasInternalStairs: hasInternalStairs ?? this.hasInternalStairs,
      hasExternalStairs: hasExternalStairs ?? this.hasExternalStairs,
      propertyDirection: propertyDirection ?? this.propertyDirection,
      streetWidth: streetWidth ?? this.streetWidth,
      livingRoomsCount: livingRoomsCount ?? this.livingRoomsCount,
      majlisCount: majlisCount ?? this.majlisCount,
      features: features ?? this.features,
      amenities: amenities ?? this.amenities,
      isNegotiable: isNegotiable ?? this.isNegotiable,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      includesUtilities: includesUtilities ?? this.includesUtilities,
      minimumRentPeriod: minimumRentPeriod ?? this.minimumRentPeriod,
      availableViewings: availableViewings ?? this.availableViewings,
      requiresAppointment: requiresAppointment ?? this.requiresAppointment,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastViewed: lastViewed ?? this.lastViewed,
      contactPhone: contactPhone,
    );
  }

  /// تحويل من JSON
  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    try {
      // ✅ التحقق من أن ID موجود وغير فارغ
      final id = json['id'] as String? ?? '';
      if (id.isEmpty) {
        logError('PropertyModel.fromJson: Property ID is empty or null', Exception('Empty property ID'));
        throw Exception('Property ID cannot be empty');
      }
      
      return PropertyModel(
        id: id,
        ownerId: json['ownerId'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        price: (json['price'] as num).toDouble(),
        purchasePrice: json['purchasePrice'] != null ? (json['purchasePrice'] as num).toDouble() : null,
        images: List<String>.from(json['images'] as List),
        address: json['address'] as String,
        location: LatLng(
          (json['location']['latitude'] as num).toDouble(),
          (json['location']['longitude'] as num).toDouble(),
        ),
        type: PropertyType.values.firstWhere(
          (e) => e.toString() == 'PropertyType.${json['type']}',
        ),
        status: PropertyStatus.values.firstWhere(
          (e) => e.toString() == 'PropertyStatus.${json['status']}',
        ),
        offerType: OfferType.values.firstWhere(
          (e) => e.toString() == 'OfferType.${json['offerType']}',
        ),
        rooms: json['rooms'] as int,
        bathrooms: json['bathrooms'] as int,
        area: (json['area'] as num).toDouble(),
        floors: json['floors'] as int? ?? 1,
        yearBuilt: json['yearBuilt'] as int? ?? 0,
        roomDetails: json['roomDetails'] != null
            ? PropertyRoomDetails.fromJson(json['roomDetails'] as Map<String, dynamic>)
            : null,
        hasApartments: json['hasApartments'] as bool? ?? false,
        hasInternalStairs: json['hasInternalStairs'] as bool? ?? false,
        hasExternalStairs: json['hasExternalStairs'] as bool? ?? false,
        propertyDirection: json['propertyDirection'] as String?,
        streetWidth: json['streetWidth'] as String?,
        livingRoomsCount: json['livingRoomsCount'] as int?,
        majlisCount: json['majlisCount'] as int?,
        features: Map<String, bool>.from(json['features'] as Map? ?? {}),
        amenities: List<String>.from(json['amenities'] as List? ?? []),
        isNegotiable: json['isNegotiable'] as bool? ?? false,
        monthlyRent: json['monthlyRent'] != null ? (json['monthlyRent'] as num).toDouble() : null,
        includesUtilities: json['includesUtilities'] as bool?,
        minimumRentPeriod: json['minimumRentPeriod'] as int?,
        availableViewings: (json['availableViewings'] as List?)
            ?.map((e) => DateTime.parse(e as String))
            .toList() ??
            [],
        requiresAppointment: json['requiresAppointment'] as bool? ?? true,
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        reviews: (json['reviews'] as List?)
            ?.map((e) => PropertyReview.fromJson(e as Map<String, dynamic>))
            .toList() ??
            [],
        createdAt: json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : json['createdAt'] is String
                ? DateTime.parse(json['createdAt'] as String)
                : DateTime.now(),
        updatedAt: json['updatedAt'] is Timestamp
            ? (json['updatedAt'] as Timestamp).toDate()
            : json['updatedAt'] is String
                ? DateTime.parse(json['updatedAt'] as String)
                : DateTime.now(),
        lastViewed: json['lastViewed'] != null
            ? (json['lastViewed'] is Timestamp
                ? (json['lastViewed'] as Timestamp).toDate()
                : json['lastViewed'] is String
                    ? DateTime.parse(json['lastViewed'] as String)
                    : null)
            : null,
        contactPhone: json['contactPhone'] as String,
        panoramaUrl: json['panoramaUrl'] as String?,
        virtualTourUrl: json['virtualTourUrl'] as String?,
        has360View: json['has360View'] as bool? ?? false,
      );
    } catch (e) {
      logError('Error parsing property from JSON', e);
      rethrow;
    }
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'price': price,
      'purchasePrice': purchasePrice, // ⚠️ حساس - لا يعرض للعامة (CRM فقط)
      'images': images,
      'address': address,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'offerType': offerType.toString().split('.').last,
      'rooms': rooms,
      'bathrooms': bathrooms,
      'area': area,
      'floors': floors,
      'yearBuilt': yearBuilt,
      'roomDetails': roomDetails?.toJson(),
      'hasApartments': hasApartments,
      'hasInternalStairs': hasInternalStairs,
      'hasExternalStairs': hasExternalStairs,
      'propertyDirection': propertyDirection,
      'streetWidth': streetWidth,
      'livingRoomsCount': livingRoomsCount,
      'majlisCount': majlisCount,
      'features': features,
      'amenities': amenities,
      'isNegotiable': isNegotiable,
      'monthlyRent': monthlyRent,
      'includesUtilities': includesUtilities,
      'minimumRentPeriod': minimumRentPeriod,
      'availableViewings': availableViewings.map((date) => date.toIso8601String()).toList(),
      'requiresAppointment': requiresAppointment,
      'rating': rating,
      'reviews': reviews.map((review) => review.toJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastViewed': lastViewed != null ? Timestamp.fromDate(lastViewed!) : null,
      'contactPhone': contactPhone,
      'panoramaUrl': panoramaUrl,
      'virtualTourUrl': virtualTourUrl,
      'has360View': has360View,
    };
  }
}

/// نموذج تقييم العقار
class PropertyReview {
  final String id;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  /// إنشاء تقييم جديد
  PropertyReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  /// تحويل من JSON
  factory PropertyReview.fromJson(Map<String, dynamic> json) {
    try {
      return PropertyReview(
        id: json['id'] as String,
        userId: json['userId'] as String,
        userName: json['userName'] as String,
        rating: (json['rating'] as num).toDouble(),
        comment: json['comment'] as String,
        createdAt: json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : json['createdAt'] is String
                ? DateTime.parse(json['createdAt'] as String)
                : DateTime.now(),
      );
    } catch (e) {
      logError('Error parsing review from JSON', e);
      rethrow;
    }
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
} 