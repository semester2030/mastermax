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
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

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

  /// بعد حذف الحساب في Firebase؛ يُفرغ التوكن والمستخدم محلياً دون استدعاء الخادم.
  void clearLocalAuthState() {
    _token = null;
    _currentUser = null;
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
        FirebaseAuthException? firebaseError;
        try {
          debugPrint('[AuthService] محاولة تسجيل الدخول عبر Firebase Auth...');
          final userCredential = await auth.signInWithEmailAndPassword(
            email: emailOrCredentials,
            password: password,
          );
          
          debugPrint('[AuthService] نجح تسجيل الدخول عبر Firebase Auth');

          // حساب الأدمن المُنشأ يدوياً من Console يكون emailVerified = false بدون رابط تفعيل
          final loginEmail =
              userCredential.user!.email?.trim().toLowerCase() ?? '';
          const bootstrapAdminEmail = 'admin@mastermax.com';
          final needsEmailVerification =
              userCredential.user != null &&
                  !userCredential.user!.emailVerified &&
                  loginEmail != bootstrapAdminEmail;

          if (needsEmailVerification) {
            debugPrint('[AuthService] البريد الإلكتروني غير مفعّل');
            await auth.signOut();
            throw Exception('يرجى تفعيل حسابك من خلال الرابط المرسل إلى بريدك الإلكتروني أولاً');
          }
          if (userCredential.user != null &&
              !userCredential.user!.emailVerified &&
              loginEmail == bootstrapAdminEmail) {
            debugPrint(
                '[AuthService] تخطي التحقق من البريد لحساب الأدمن الافتراضي (Console)');
          }

          debugPrint('[AuthService] البريد الإلكتروني جاهز للمتابعة');
          
          // إذا نجح Firebase Auth، نجلب بيانات المستخدم من Firestore
          try {
            debugPrint('[AuthService] جلب بيانات المستخدم من Firestore...');
            final userDoc = await _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .get();
            
            if (userDoc.exists) {
              debugPrint('[AuthService] تم العثور على بيانات المستخدم في Firestore');
              final userData = userDoc.data()!;
              userData['id'] = userDoc.id;
              final firestoreEmail = userData['email']?.toString().trim() ?? '';
              if (firestoreEmail.isEmpty &&
                  userCredential.user!.email != null &&
                  userCredential.user!.email!.trim().isNotEmpty) {
                userData['email'] = userCredential.user!.email!.trim();
              }

              // إنشاء token من Firebase ID token
              final idToken = await userCredential.user!.getIdToken();
              _token = idToken;
              
              // تحويل بيانات Firestore إلى User model
              _currentUser = app_models.User.fromJson(userData);
              
              debugPrint('[AuthService] تم تسجيل الدخول بنجاح باستخدام Firebase');
              
              // تسجيل نجاح تسجيل الدخول
              await _auditLog.logSecurityEvent(
                userId: _currentUser!.id,
                eventType: SecurityEventType.login,
                details: 'تم تسجيل الدخول بنجاح عبر Firebase',
              );
              
              return _currentUser!;
            } else {
              debugPrint('[AuthService] المستخدم غير موجود في Firestore، سيتم المحاولة عبر API');
              if (loginEmail == bootstrapAdminEmail) {
                final fbUser = userCredential.user!;
                final idToken = await fbUser.getIdToken();
                _token = idToken;
                _currentUser = app_models.User(
                  id: fbUser.uid,
                  name: fbUser.displayName?.trim().isNotEmpty == true
                      ? fbUser.displayName!.trim()
                      : 'Admin',
                  email: fbUser.email?.trim() ?? loginEmail,
                  type: UserType.individual,
                  extraData: const {'isAdmin': true},
                );
                debugPrint(
                    '[AuthService] دخول أدمن بدون مستند Firestore (حساب Authentication فقط)');
                await _auditLog.logSecurityEvent(
                  userId: _currentUser!.id,
                  eventType: SecurityEventType.login,
                  details: 'تسجيل دخول أدمن (Firebase Auth فقط)',
                );
                return _currentUser!;
              }
            }
          } catch (e) {
            debugPrint('[AuthService] خطأ في جلب بيانات Firestore: $e');
            // نتابع المحاولة عبر API
          }
        } catch (e) {
          debugPrint('[AuthService] خطأ في Firebase Auth: $e');
          firebaseError = e is FirebaseAuthException ? e : null;
          
          // معالجة أخطاء Firebase Auth بشكل أفضل
          final errorString = e.toString().toLowerCase();
          final errorCode = firebaseError?.code ?? '';
          
          // معالجة invalid-credential (يمكن أن يعني كلمة مرور خاطئة أو مستخدم غير موجود)
          if (errorCode == 'invalid-credential' || 
              errorString.contains('invalid-credential') ||
              errorString.contains('credential is malformed') ||
              errorString.contains('credential is malformed or has expired')) {
            debugPrint('[AuthService] بيانات الاعتماد غير صحيحة');
            debugPrint('[AuthService] البريد: $emailOrCredentials');
            debugPrint('[AuthService] كود الخطأ: $errorCode');
            
            // محاولة التحقق من وجود المستخدم
            try {
              debugPrint('[AuthService] التحقق من وجود المستخدم...');
              final methods = await auth.fetchSignInMethodsForEmail(emailOrCredentials.trim());
              debugPrint('[AuthService] طرق تسجيل الدخول المتاحة: $methods');
              
              if (methods.isEmpty) {
                debugPrint('[AuthService] المستخدم غير موجود في Firebase Auth');
                throw Exception('البريد الإلكتروني غير مسجل في النظام');
              } else {
                debugPrint('[AuthService] المستخدم موجود لكن كلمة المرور خاطئة');
                // التحقق من أن كلمة المرور ليست فارغة
                if (password.trim().isEmpty) {
                  throw Exception('كلمة المرور مطلوبة');
                }
                throw Exception('كلمة المرور غير صحيحة. يرجى التحقق من كلمة المرور أو استخدم "نسيت كلمة المرور" لإعادة تعيينها');
              }
            } catch (checkError) {
              debugPrint('[AuthService] خطأ في التحقق: $checkError');
              // إذا فشل التحقق، نعطي رسالة عامة
              if (checkError.toString().contains('البريد الإلكتروني غير مسجل')) {
                rethrow;
              } else if (checkError.toString().contains('كلمة المرور')) {
                rethrow;
              } else {
                // رسالة أكثر وضوحاً
                throw Exception('البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى التحقق من:\n1. البريد الإلكتروني صحيح\n2. كلمة المرور صحيحة\n3. الحساب مفعّل من البريد الإلكتروني');
              }
            }
          } else if (errorString.contains('user-not-found') || 
                     errorString.contains('there is no user record')) {
            debugPrint('[AuthService] المستخدم غير موجود');
            throw Exception('البريد الإلكتروني غير مسجل');
          } else if (errorString.contains('wrong-password') || 
                     errorString.contains('password is invalid') ||
                     errorString.contains('invalid password')) {
            debugPrint('[AuthService] كلمة المرور خاطئة');
            throw Exception('كلمة المرور غير صحيحة');
          } else if (errorString.contains('invalid-email') ||
                     errorString.contains('invalid email')) {
            debugPrint('[AuthService] البريد الإلكتروني غير صالح');
            throw Exception('البريد الإلكتروني غير صالح');
          } else if (errorString.contains('user-disabled')) {
            debugPrint('[AuthService] الحساب معطّل');
            throw Exception('تم تعطيل هذا الحساب');
          } else if (errorString.contains('too-many-requests')) {
            debugPrint('[AuthService] تم تجاوز عدد المحاولات');
            throw Exception('تم تجاوز عدد المحاولات المسموح بها. يرجى المحاولة لاحقاً');
          } else if (errorString.contains('network') ||
                     errorString.contains('connection')) {
            debugPrint('[AuthService] خطأ في الاتصال');
            throw Exception('خطأ في الاتصال بالإنترنت');
          }
          // إذا كان الخطأ من Firebase Auth لكن لم نتعرف عليه، أعد رميه
          debugPrint('[AuthService] خطأ غير معروف في Firebase Auth: $e');
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

      debugPrint('[AuthService] إرسال طلب تسجيل الدخول إلى API: $baseUrl/auth/login');
      debugPrint('[AuthService] Body: ${json.encode(body)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[AuthService] انتهت مهلة الاتصال بالخادم');
          throw Exception('انتهت مهلة الاتصال بالخادم. يرجى المحاولة مرة أخرى');
        },
      );

      debugPrint('[AuthService] استجابة API - Status Code: ${response.statusCode}');
      debugPrint('[AuthService] استجابة API - Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          
          if (data['token'] == null || data['user'] == null) {
            throw Exception('استجابة غير صحيحة من الخادم: بيانات ناقصة');
          }
          
          _token = data['token'] as String;
          _currentUser = app_models.User.fromJson(data['user'] as Map<String, dynamic>);

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
        } catch (e) {
          await _auditLog.logSecurityEvent(
            userId: identifier,
            eventType: SecurityEventType.failedLogin,
            details: 'خطأ في معالجة استجابة الخادم: $e',
          );
          throw Exception('خطأ في معالجة استجابة الخادم: $e');
        }
      } else {
        // محاولة استخراج رسالة الخطأ من response body
        String errorMessage = 'فشل تسجيل الدخول';
        try {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          if (errorData['message'] != null) {
            errorMessage = errorData['message'] as String;
          } else if (errorData['error'] != null) {
            errorMessage = errorData['error'] as String;
          }
        } catch (_) {
          // إذا فشل parsing، استخدم رسالة افتراضية بناءً على status code
          switch (response.statusCode) {
            case 401:
              errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
              break;
            case 400:
              errorMessage = 'بيانات تسجيل الدخول غير صحيحة';
              break;
            case 404:
              errorMessage = 'البريد الإلكتروني غير مسجل';
              break;
            case 500:
              errorMessage = 'خطأ في الخادم، يرجى المحاولة لاحقاً';
              break;
            default:
              errorMessage = 'فشل تسجيل الدخول (${response.statusCode})';
          }
        }
        
        await _auditLog.logSecurityEvent(
          userId: identifier,
          eventType: SecurityEventType.failedLogin,
          details: 'فشل تسجيل الدخول: ${response.statusCode} - $errorMessage',
        );
        throw Exception(errorMessage);
      }
    } catch (e) {
      // إذا كان الخطأ من Firebase Auth، أعد رميه كما هو
      if (e.toString().contains('البريد الإلكتروني غير مسجل') ||
          e.toString().contains('كلمة المرور غير صحيحة') ||
          e.toString().contains('يرجى تفعيل حسابك')) {
        rethrow;
      }
      
      // إذا كان الخطأ Exception مع رسالة واضحة، أعد رميه
      if (e is Exception) {
        rethrow;
      }
      
      // خلاف ذلك، أضف معلومات إضافية
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