import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/property_type.dart';
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

/// نموذج بيانات العقار
class PropertyModel {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final double price;
  final List<String> images;
  final String? panoramaUrl;
  final String? virtualTourUrl;
  final bool has360View;
  final String address;
  final Point location;
  final PropertyType type;
  final PropertyStatus status;
  final OfferType offerType;
  
  // معلومات أساسية
  final int rooms;
  final int bathrooms;
  final double area;
  final int floors;
  final int yearBuilt;
  
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
      images: [],
      address: '',
      location: Point(coordinates: Position(0, 0)),
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
    String? title,
    String? description,
    double? price,
    List<String>? images,
    String? panoramaUrl,
    String? virtualTourUrl,
    bool? has360View,
    String? address,
    Point? location,
    PropertyType? type,
    PropertyStatus? status,
    OfferType? offerType,
    int? rooms,
    int? bathrooms,
    double? area,
    int? floors,
    int? yearBuilt,
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
      return PropertyModel(
        id: json['id'] as String,
        ownerId: json['ownerId'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        price: (json['price'] as num).toDouble(),
        images: List<String>.from(json['images'] as List),
        address: json['address'] as String,
        location: Point(
          coordinates: Position(
            (json['location']['longitude'] as num).toDouble(),
            (json['location']['latitude'] as num).toDouble(),
          ),
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
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        lastViewed: json['lastViewed'] != null
            ? DateTime.parse(json['lastViewed'] as String)
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
      'images': images,
      'address': address,
      'location': {
        'latitude': location.coordinates.lat,
        'longitude': location.coordinates.lng,
      },
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'offerType': offerType.toString().split('.').last,
      'rooms': rooms,
      'bathrooms': bathrooms,
      'area': area,
      'floors': floors,
      'yearBuilt': yearBuilt,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastViewed': lastViewed?.toIso8601String(),
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
        createdAt: DateTime.parse(json['createdAt'] as String),
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
      'createdAt': createdAt.toIso8601String(),
    };
  }
} 