import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../models/user_type.dart';

class AuthState extends ChangeNotifier {
  final AuthService _authService;
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isTrialMode = false;
  UserType? _trialUserType;
  bool _isInitialized = false;
  UserType _userType = UserType.individual;
  final bool _isLoggedIn = false;

  AuthState() : _authService = AuthService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;
  UserType get userType => _userType;
  bool get isTrialMode => _isTrialMode;
  UserType? get trialUserType => _trialUserType;
  
  bool get isAdmin {
    if (_user == null) return false;
    return _user?.email == 'admin@mastermax.com' || 
           _user?.extraData?['isAdmin'] == true;
  }

  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _user = await _authService.getCurrentUser();
      
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

  Future<void> checkAuthStatus() async {
    try {
      _isLoading = true;
      notifyListeners();

      _user = await _authService.getCurrentUser();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginAsGuest() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _isTrialMode = true;
      _trialUserType = UserType.realEstateCompany;
      _userType = UserType.realEstateCompany;
      _user = User(
        id: 'trial_user',
        name: 'مستخدم تجريبي',
        email: 'admin@mastermax.com',
        type: UserType.realEstateCompany,
        extraData: {
          'isTrial': true,
          'hasFullAccess': true,
          'isAdmin': true,
          'phoneNumber': '+966500000000',
          'isVerified': true,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      
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

  void setTrialMode() {
    _isTrialMode = true;
    _isLoading = false;
    _user = User(
      id: 'trial_user',
      name: 'مستخدم تجريبي',
      email: 'trial@example.com',
      type: UserType.realEstateCompany,
      extraData: {
        'isTrial': true,
        'hasFullAccess': true,
        'phoneNumber': '+966500000000',
        'isVerified': true,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
    notifyListeners();
  }

  void exitTrialMode() {
    _isTrialMode = false;
    _trialUserType = null;
    _user = null;
    notifyListeners();
  }

  void setUserType(UserType type) {
    _userType = type;
    notifyListeners();
  }
} 