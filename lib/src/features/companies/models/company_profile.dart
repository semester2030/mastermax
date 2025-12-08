import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String logo;
  final String coverImage;
  final String description;
  final String address;
  final String website;
  final String commercialRegister;
  final bool isVerified;
  final String subscriptionPlan;
  final DateTime subscriptionEndDate;
  final List<String> teamMembers;
  final Map<String, String> socialLinks;
  final CompanyStats stats;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.logo,
    required this.coverImage,
    required this.description,
    required this.address,
    required this.website,
    required this.commercialRegister,
    required this.isVerified,
    required this.subscriptionPlan,
    required this.subscriptionEndDate,
    required this.teamMembers,
    required this.socialLinks,
    required this.stats,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyProfile(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      logo: data['logo'] ?? '',
      coverImage: data['coverImage'] ?? '',
      description: data['description'] ?? '',
      address: data['address'] ?? '',
      website: data['website'] ?? '',
      commercialRegister: data['commercialRegister'] ?? '',
      isVerified: data['isVerified'] ?? false,
      subscriptionPlan: data['subscriptionPlan'] ?? 'free',
      subscriptionEndDate: (data['subscriptionEndDate'] as Timestamp).toDate(),
      teamMembers: List<String>.from(data['teamMembers'] ?? []),
      socialLinks: Map<String, String>.from(data['socialLinks'] ?? {}),
      stats: CompanyStats.fromMap(data['stats'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'logo': logo,
      'coverImage': coverImage,
      'description': description,
      'address': address,
      'website': website,
      'commercialRegister': commercialRegister,
      'isVerified': isVerified,
      'subscriptionPlan': subscriptionPlan,
      'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
      'teamMembers': teamMembers,
      'socialLinks': socialLinks,
      'stats': stats.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class CompanyStats {
  final int totalListings;
  final int activeListings;
  final int totalViews;
  final int totalLeads;
  final int totalSales;
  final Map<String, int> viewsByMonth;
  final Map<String, int> leadsByMonth;

  CompanyStats({
    required this.totalListings,
    required this.activeListings,
    required this.totalViews,
    required this.totalLeads,
    required this.totalSales,
    required this.viewsByMonth,
    required this.leadsByMonth,
  });

  factory CompanyStats.fromMap(Map<String, dynamic> map) {
    return CompanyStats(
      totalListings: map['totalListings'] ?? 0,
      activeListings: map['activeListings'] ?? 0,
      totalViews: map['totalViews'] ?? 0,
      totalLeads: map['totalLeads'] ?? 0,
      totalSales: map['totalSales'] ?? 0,
      viewsByMonth: Map<String, int>.from(map['viewsByMonth'] ?? {}),
      leadsByMonth: Map<String, int>.from(map['leadsByMonth'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalListings': totalListings,
      'activeListings': activeListings,
      'totalViews': totalViews,
      'totalLeads': totalLeads,
      'totalSales': totalSales,
      'viewsByMonth': viewsByMonth,
      'leadsByMonth': leadsByMonth,
    };
  }
} 