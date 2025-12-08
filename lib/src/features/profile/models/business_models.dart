import 'package:cloud_firestore/cloud_firestore.dart';

class Listing {
  final String id;
  final String businessId;
  final String title;
  final String description;
  final double price;
  final String category;
  final String type; // عقار/سيارة
  final List<String> images;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // نشط/منتهي/محجوز

  Listing({
    required this.id,
    required this.businessId,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.type,
    required this.images,
    required this.details,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'],
      businessId: json['businessId'],
      title: json['title'],
      description: json['description'],
      price: json['price'].toDouble(),
      category: json['category'],
      type: json['type'],
      images: List<String>.from(json['images']),
      details: Map<String, dynamic>.from(json['details']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'type': type,
      'images': images,
      'details': details,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
    };
  }
}

class TeamMember {
  final String id;
  final String businessId;
  final String name;
  final String email;
  final String role;
  final List<String> permissions;
  final DateTime joinedAt;
  final String status; // نشط/معلق/محظور

  TeamMember({
    required this.id,
    required this.businessId,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    required this.joinedAt,
    required this.status,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'],
      businessId: json['businessId'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      permissions: List<String>.from(json['permissions']),
      joinedAt: DateTime.parse(json['joinedAt']),
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'name': name,
      'email': email,
      'role': role,
      'permissions': permissions,
      'joinedAt': joinedAt.toIso8601String(),
      'status': status,
    };
  }
}

class BusinessSettings {
  final String businessId;
  final String name;
  final String description;
  final String logo;
  final String address;
  final String phone;
  final String email;
  final Map<String, bool> features;
  final Map<String, String> preferences;
  final NotificationSettings notificationSettings;

  BusinessSettings({
    required this.businessId,
    required this.name,
    required this.description,
    required this.logo,
    required this.address,
    required this.phone,
    required this.email,
    required this.features,
    required this.preferences,
    required this.notificationSettings,
  });

  factory BusinessSettings.fromJson(Map<String, dynamic> json) {
    return BusinessSettings(
      businessId: json['businessId'],
      name: json['name'],
      description: json['description'],
      logo: json['logo'],
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      features: Map<String, bool>.from(json['features']),
      preferences: Map<String, String>.from(json['preferences']),
      notificationSettings: NotificationSettings.fromJson(json['notificationSettings']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessId': businessId,
      'name': name,
      'description': description,
      'logo': logo,
      'address': address,
      'phone': phone,
      'email': email,
      'features': features,
      'preferences': preferences,
      'notificationSettings': notificationSettings.toJson(),
    };
  }
}

class NotificationSettings {
  final bool email;
  final bool push;
  final bool sms;
  final Map<String, bool> types;

  NotificationSettings({
    required this.email,
    required this.push,
    required this.sms,
    required this.types,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      email: json['email'],
      push: json['push'],
      sms: json['sms'],
      types: Map<String, bool>.from(json['types']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'push': push,
      'sms': sms,
      'types': types,
    };
  }
}

class BusinessNotification {
  final String id;
  final String businessId;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;

  BusinessNotification({
    required this.id,
    required this.businessId,
    required this.title,
    required this.message,
    required this.type,
    required this.data,
    required this.createdAt,
    required this.isRead,
  });

  factory BusinessNotification.fromJson(Map<String, dynamic> json) {
    return BusinessNotification(
      id: json['id'],
      businessId: json['businessId'],
      title: json['title'],
      message: json['message'],
      type: json['type'],
      data: Map<String, dynamic>.from(json['data']),
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'title': title,
      'message': message,
      'type': type,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }
}

class Business {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final String type;
  final String category;
  final String address;
  final GeoPoint location;
  final String phone;
  final String email;
  final String website;
  final List<String> images;
  final String mainImage;
  final Map<String, dynamic> socialMedia;
  final Map<String, dynamic> workingHours;
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> extraData;

  Business({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.type,
    required this.category,
    required this.address,
    required this.location,
    required this.phone,
    required this.email,
    required this.images, required this.mainImage, required this.socialMedia, required this.workingHours, required this.createdAt, required this.updatedAt, this.website = '',
    this.isVerified = false,
    this.isActive = true,
    this.extraData = const {},
  });

  factory Business.fromMap(Map<String, dynamic> map, String id) {
    return Business(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      ownerId: map['ownerId'] ?? '',
      type: map['type'] ?? '',
      category: map['category'] ?? '',
      address: map['address'] ?? '',
      location: map['location'] ?? const GeoPoint(0, 0),
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      website: map['website'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      mainImage: map['mainImage'] ?? '',
      socialMedia: Map<String, dynamic>.from(map['socialMedia'] ?? {}),
      workingHours: Map<String, dynamic>.from(map['workingHours'] ?? {}),
      isVerified: map['isVerified'] ?? false,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      extraData: Map<String, dynamic>.from(map['extraData'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'type': type,
      'category': category,
      'address': address,
      'location': location,
      'phone': phone,
      'email': email,
      'website': website,
      'images': images,
      'mainImage': mainImage,
      'socialMedia': socialMedia,
      'workingHours': workingHours,
      'isVerified': isVerified,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'extraData': extraData,
    };
  }
} 