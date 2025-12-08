import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart' as app_models;
import '../models/user_type.dart';
import '../models/auth_credentials.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_security_layer.dart';
import 'auth_validation_layer.dart';
import 'security_audit_log.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final String baseUrl;
  app_models.User? _currentUser;
  String? _token;
  final FirebaseFirestore _firestore;
  
  // إضافة طبقات الأمان والتحقق
  final _securityLayer = AuthSecurityLayer();
  final _validationLayer = AuthValidationLayer();
  final _deviceInfo = DeviceInfoPlugin();
  final _auditLog = SecurityAuditLog();

  AuthService({
    this.baseUrl = 'https://mastermax.net/api/v1',
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<bool> verifySSLCertificate() async {
    try {
      if (kIsWeb) {
        // في الويب، نعتمد على المتصفح للتحقق من الشهادة
        return true;
      }
      
      final response = await http.get(Uri.parse(baseUrl));
      return response.statusCode == 200;
    } catch (e) {
      print('SSL Certificate Error: $e');
      return false;
    }
  }

  Future<app_models.User?> getCurrentUser() async {
    return _currentUser;
  }

  String? getToken() {
    return _token;
  }

  Future<void> saveToken(String token) async {
    _token = token;
    // تحديث نشاط الجلسة عند حفظ التوكن
    await _securityLayer.updateSessionActivity(token);
  }

  Future<void> clearToken() async {
    if (_token != null) {
      await _securityLayer.invalidateAllSessions(_currentUser?.id ?? '');
    }
    _token = null;
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = await _deviceInfo.deviceInfo;
    return deviceInfo.data['id'] ?? DateTime.now().toString();
  }

  Future<app_models.User> login(dynamic emailOrCredentials, [String? password]) async {
    try {
      Map<String, dynamic> body;
      String identifier = 'unknown';
      
      // التحقق من صحة المدخلات
      if (emailOrCredentials is AuthCredentials) {
        body = emailOrCredentials.toJson();
        identifier = emailOrCredentials.email.isNotEmpty ? 
          emailOrCredentials.email : 
          emailOrCredentials.phoneNumber ?? 'unknown';
      } else if (emailOrCredentials is String && password != null) {
        // التحقق من صحة البريد الإلكتروني وكلمة المرور
        final emailValidation = _validationLayer.validateEmail(emailOrCredentials);
        final passwordValidation = _validationLayer.validatePassword(password);
        
        if (!emailValidation.isValid) {
          await _auditLog.logSecurityEvent(
            userId: identifier,
            eventType: SecurityEventType.failedLogin,
            details: 'فشل التحقق من البريد الإلكتروني: ${emailValidation.message}',
          );
          throw Exception(emailValidation.message);
        }
        if (!passwordValidation.isValid) {
          await _auditLog.logSecurityEvent(
            userId: identifier,
            eventType: SecurityEventType.failedLogin,
            details: 'فشل التحقق من كلمة المرور: ${passwordValidation.message}',
          );
          throw Exception(passwordValidation.message);
        }

        // التحقق من تفعيل البريد الإلكتروني
        final auth = FirebaseAuth.instance;
        try {
          final userCredential = await auth.signInWithEmailAndPassword(
            email: emailOrCredentials,
            password: password,
          );
          
          if (userCredential.user != null && !userCredential.user!.emailVerified) {
            await auth.signOut();
            throw Exception('يرجى تفعيل حسابك من خلال الرابط المرسل إلى بريدك الإلكتروني أولاً');
          }
        } catch (e) {
          if (e.toString().contains('user-not-found')) {
            throw Exception('البريد الإلكتروني غير مسجل');
          } else if (e.toString().contains('wrong-password')) {
            throw Exception('كلمة المرور غير صحيحة');
          }
          rethrow;
        }

        body = {
          'email': emailOrCredentials,
          'password': password,
        };
        identifier = emailOrCredentials;
      } else {
        await _auditLog.logSecurityEvent(
          userId: identifier,
          eventType: SecurityEventType.failedLogin,
          details: 'محاولة تسجيل دخول غير صالحة',
        );
        throw ArgumentError('معلومات تسجيل الدخول غير صحيحة');
      }

      // التحقق من محاولات تسجيل الدخول
      if (!await _securityLayer.checkLoginAttempt(identifier)) {
        await _auditLog.logSecurityEvent(
          userId: identifier,
          eventType: SecurityEventType.accountLocked,
          details: 'تم قفل الحساب بسبب تجاوز عدد محاولات تسجيل الدخول',
        );
        throw Exception('تم تجاوز الحد الأقصى لمحاولات تسجيل الدخول. الرجاء المحاولة لاحقاً');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        _currentUser = app_models.User.fromJson(data['user']);

        // إضافة الجهاز كجهاز موثوق
        final deviceId = await _getDeviceId();
        await _securityLayer.addTrustedDevice(_currentUser!.id, deviceId);
        
        // تحديث نشاط الجلسة
        await _securityLayer.updateSessionActivity(_token!);

        // تسجيل نجاح تسجيل الدخول
        await _auditLog.logSecurityEvent(
          userId: _currentUser!.id,
          eventType: SecurityEventType.login,
          details: 'تم تسجيل الدخول بنجاح',
        );

        return _currentUser!;
      } else {
        await _auditLog.logSecurityEvent(
          userId: identifier,
          eventType: SecurityEventType.failedLogin,
          details: 'فشل تسجيل الدخول: ${response.statusCode}',
        );
        throw Exception('فشل تسجيل الدخول');
      }
    } catch (e) {
      throw Exception('خطأ في تسجيل الدخول: $e');
    }
  }

  Future<app_models.User> register({
    String? name,
    String? email,
    String? password,
    UserType? type,
    String? phoneNumber,
    RegisterCredentials? credentials,
  }) async {
    try {
      Map<String, dynamic> body;
      
      // التحقق من صحة المدخلات
      if (credentials != null) {
        body = credentials.toJson();
      } else {
        // التحقق من صحة البريد الإلكتروني وكلمة المرور فقط
        if (email != null) {
          final emailValidation = _validationLayer.validateEmail(email);
          if (!emailValidation.isValid) {
            throw Exception(emailValidation.message);
          }
        }
        
        if (password != null) {
          final passwordValidation = _validationLayer.validatePassword(password);
          if (!passwordValidation.isValid) {
            throw Exception(passwordValidation.message);
          }
        }
        
        // تم تعليق التحقق من رقم الجوال مؤقتاً
        // if (phoneNumber != null) {
        //   final phoneValidation = _validationLayer.validatePhone(phoneNumber);
        //   if (!phoneValidation.isValid) {
        //     throw Exception(phoneValidation.message);
        //   }
        // }

        if (name != null && email != null && password != null && type != null) {
          body = {
            'name': name,
            'email': email,
            'password': password,
            'type': type.toString(),
            // تم تعليق إضافة رقم الجوال مؤقتاً
            // if (phoneNumber != null) 'phoneNumber': phoneNumber,
          };
        } else {
          throw ArgumentError('معلومات التسجيل غير مكتملة');
        }
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _token = data['token'];
        _currentUser = app_models.User.fromJson(data['user']);

        // تم تعليق إضافة الجهاز كجهاز موثوق مؤقتاً حتى يتم تفعيل التحقق عبر الجوال مرة أخرى
        // final deviceId = await _getDeviceId();
        // await _securityLayer.addTrustedDevice(_currentUser!.id, deviceId);
        
        // تحديث نشاط الجلسة
        await _securityLayer.updateSessionActivity(_token!);

        return _currentUser!;
      } else {
        throw Exception('فشل التسجيل');
      }
    } catch (e) {
      throw Exception('خطأ في التسجيل: $e');
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null && _currentUser != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
        );
        
        // تسجيل تسجيل الخروج
        await _auditLog.logSecurityEvent(
          userId: _currentUser!.id,
          eventType: SecurityEventType.logout,
          details: 'تم تسجيل الخروج بنجاح',
        );
        
        // إيقاف جميع الجلسات
        await _securityLayer.invalidateAllSessions(_currentUser!.id);
      }
    } finally {
      _token = null;
      _currentUser = null;
    }
  }

  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    try {
      // التحقق من صحة رقم الهاتف ورمز التحقق
      final phoneValidation = _validationLayer.validatePhone(phoneNumber);
      final otpValidation = _validationLayer.validateOTP(otp);

      if (!phoneValidation.isValid) {
        throw Exception(phoneValidation.message);
      }
      if (!otpValidation.isValid) {
        throw Exception(otpValidation.message);
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phoneNumber': phoneNumber,
          'otp': otp,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('خطأ في التحقق من الرمز: $e');
    }
  }

  Future<void> sendOtp(String phoneNumber) async {
    try {
      // التحقق من صحة رقم الهاتف
      final validation = _validationLayer.validatePhone(phoneNumber);
      if (!validation.isValid) {
        throw Exception(validation.message);
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phoneNumber': phoneNumber}),
      );

      if (response.statusCode != 200) {
        throw Exception('فشل إرسال رمز التحقق');
      }
    } catch (e) {
      throw Exception('خطأ في إرسال الرمز: $e');
    }
  }

  Future<app_models.User> loginAsGuest() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/guest'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        _currentUser = app_models.User.fromJson(data['user']);
        
        // تحديث نشاط الجلسة للزائر
        await _securityLayer.updateSessionActivity(_token!);

        return _currentUser!;
      } else {
        throw Exception('فشل تسجيل الدخول كزائر');
      }
    } catch (e) {
      throw Exception('خطأ في تسجيل الدخول كزائر: $e');
    }
  }

  Future<app_models.User> updateUserType(String userId, UserType type) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'type': type.toString().split('.').last,
      });

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data()!;
      userData['id'] = userDoc.id;
      return app_models.User.fromJson(userData);
    } catch (e) {
      throw Exception('فشل تحديث نوع المستخدم: $e');
    }
  }

  // دالة للتحقق من صلاحية الجلسة
  Future<bool> isSessionValid() async {
    if (_token == null) return false;
    return _securityLayer.isSessionValid(_token!);
  }

  // دالة للتحقق من الجهاز
  Future<bool> isDeviceTrusted() async {
    if (_currentUser == null) return false;
    final deviceId = await _getDeviceId();
    return _securityLayer.isDeviceTrusted(_currentUser!.id, deviceId);
  }
} 