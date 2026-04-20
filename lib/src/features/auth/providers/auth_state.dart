import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import '../services/auth_service.dart';
import '../services/account_deletion_service.dart';
import '../models/user.dart';
import '../models/user_type.dart';

class AuthState extends ChangeNotifier {
  final AuthService _authService;
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  UserType _userType = UserType.individual;

  AuthState() : _authService = AuthService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;
  UserType get userType => _userType;
  /// لا يوجد وضع تجريبي في الإنتاج؛ يُبقى للتوافق مع واجهة الملف الشخصي.
  bool get isTrialMode => false;

  static const String _adminLoginEmail = 'admin@mastermax.com';

  /// بريد الأدمن أو علم isAdmin في وثيقة المستخدم (Firestore / API).
  bool get isAdmin {
    if (_user == null) return false;

    bool flagTrue(dynamic v) =>
        v == true || v == 'true' || v == 1;

    final userEmail = _user!.email.trim().toLowerCase();
    if (userEmail == _adminLoginEmail) return true;

    final extra = _user!.extraData;
    if (extra != null && flagTrue(extra['isAdmin'])) return true;

    // جلسة Firebase (مهم عندما يكون email في Firestore فارغاً أو مسار API فقط)
    final authEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (authEmail == _adminLoginEmail) return true;

    return false;
  }

  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _user = await _authService.getCurrentUser();
      // تحديث نوع المستخدم من بيانات المستخدم الفعلية
      if (_user != null) {
        _userType = _user!.type;
      }
      
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void setAuthenticated(User user) {
    _user = user;
    // تحديث نوع المستخدم من بيانات المستخدم الفعلية
    _userType = user.type;
    _error = null;
    _isInitialized = true;
    notifyListeners();
  }

  void setError(String error) {
    _error = error;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _user = await _authService.login(email, password);
      // تحديث نوع المستخدم من بيانات المستخدم الفعلية
      if (_user != null) {
        _userType = _user!.type;
      }
      _isInitialized = true;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String name, String email, String password, UserType type) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _user = await _authService.register(
        name: name,
        email: email,
        password: password,
        type: type,
      );
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.logout();
      _user = null;
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// حذف الحساب نهائياً (Firebase Auth + بيانات مملوكة في Firestore). يتطلب كلمة المرور.
  Future<void> deleteAccount(String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final service = AccountDeletionService();
      await service.deleteAccountWithPassword(password);
      _authService.clearLocalAuthState();
      _user = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      _isLoading = true;
      notifyListeners();

      _user = await _authService.getCurrentUser();
      // تحديث نوع المستخدم من بيانات المستخدم الفعلية
      if (_user != null) {
        _userType = _user!.type;
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _authService.verifyOtp(phoneNumber, otp);
      
      _isLoading = false;
      notifyListeners();
      
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> sendOtp(String phoneNumber) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.sendOtp(phoneNumber);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> updateUserType(UserType type) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_user != null) {
        final updatedUser = await _authService.updateUserType(_user!.id, type);
        _user = updatedUser;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUserType(UserType type) {
    _userType = type;
    notifyListeners();
  }
} 