import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_models.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/config/api_config.dart';
import 'package:flutter/foundation.dart';

class BusinessService {
  final AuthService _authService;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _baseUrl = ApiConfig.baseUrl;
  final String _collection = 'businesses';

  BusinessService(this._authService);

  // إدارة العروض
  Future<List<Listing>> getListings(String businessId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/business/$businessId/listings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Listing.fromJson(json)).toList();
      } else {
        throw Exception('فشل في جلب العروض');
      }
    } catch (e) {
      throw Exception('خطأ في جلب العروض: $e');
    }
  }

  Future<void> addListing(String businessId, Listing listing) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/business/$businessId/listings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(listing.toJson()),
      );

      if (response.statusCode != 201) {
        throw Exception('فشل في إضافة العرض');
      }
    } catch (e) {
      throw Exception('خطأ في إضافة العرض: $e');
    }
  }

  Future<void> updateListing(String businessId, Listing listing) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/business/$businessId/listings/${listing.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(listing.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في تحديث العرض');
      }
    } catch (e) {
      throw Exception('خطأ في تحديث العرض: $e');
    }
  }

  Future<void> deleteListing(String businessId, String listingId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/business/$businessId/listings/$listingId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في حذف العرض');
      }
    } catch (e) {
      throw Exception('خطأ في حذف العرض: $e');
    }
  }

  // إدارة الفريق
  Future<List<TeamMember>> getTeamMembers(String businessId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/business/$businessId/team'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => TeamMember.fromJson(json)).toList();
      } else {
        throw Exception('فشل في جلب أعضاء الفريق');
      }
    } catch (e) {
      throw Exception('خطأ في جلب أعضاء الفريق: $e');
    }
  }

  Future<void> addTeamMember(String businessId, TeamMember member) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/business/$businessId/team'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(member.toJson()),
      );

      if (response.statusCode != 201) {
        throw Exception('فشل في إضافة عضو الفريق');
      }
    } catch (e) {
      throw Exception('خطأ في إضافة عضو الفريق: $e');
    }
  }

  Future<void> updateTeamMember(String businessId, TeamMember member) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/business/$businessId/team/${member.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(member.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في تحديث عضو الفريق');
      }
    } catch (e) {
      throw Exception('خطأ في تحديث عضو الفريق: $e');
    }
  }

  Future<void> removeTeamMember(String businessId, String memberId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/business/$businessId/team/$memberId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في إزالة عضو الفريق');
      }
    } catch (e) {
      throw Exception('خطأ في إزالة عضو الفريق: $e');
    }
  }

  // إعدادات الشركة
  Future<BusinessSettings> getBusinessSettings(String businessId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/business/$businessId/settings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return BusinessSettings.fromJson(json.decode(response.body));
      } else {
        throw Exception('فشل في جلب إعدادات الشركة');
      }
    } catch (e) {
      throw Exception('خطأ في جلب إعدادات الشركة: $e');
    }
  }

  Future<void> updateBusinessSettings(String businessId, BusinessSettings settings) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/business/$businessId/settings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(settings.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في تحديث إعدادات الشركة');
      }
    } catch (e) {
      throw Exception('خطأ في تحديث إعدادات الشركة: $e');
    }
  }

  // نظام الإشعارات
  Future<List<BusinessNotification>> getNotifications(String businessId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/business/$businessId/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => BusinessNotification.fromJson(json)).toList();
      } else {
        throw Exception('فشل في جلب الإشعارات');
      }
    } catch (e) {
      throw Exception('خطأ في جلب الإشعارات: $e');
    }
  }

  Future<void> markNotificationAsRead(String businessId, String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final token = await user.getIdToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/business/$businessId/notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في تحديث حالة الإشعار');
      }
    } catch (e) {
      throw Exception('خطأ في تحديث حالة الإشعار: $e');
    }
  }

  Future<void> updateBusinessInfo(String businessId, Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .update(data);
    } catch (e) {
      debugPrint('Error updating business info: $e');
      rethrow;
    }
  }

  Future<List<Business>> getBusinesses() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      return snapshot.docs.map((doc) => Business.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to get businesses: $e');
    }
  }

  Future<Business?> getBusiness(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return Business.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get business: $e');
    }
  }

  Future<Business> createBusiness(Business business) async {
    try {
      final docRef = await _firestore.collection(_collection).add(business.toMap());
      final doc = await docRef.get();
      return Business.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to create business: $e');
    }
  }

  Future<Business> updateBusiness(String id, Business business) async {
    try {
      await _firestore.collection(_collection).doc(id).update(business.toMap());
      final doc = await _firestore.collection(_collection).doc(id).get();
      return Business.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to update business: $e');
    }
  }

  Future<void> deleteBusiness(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete business: $e');
    }
  }
} 