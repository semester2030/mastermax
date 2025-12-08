import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserType {
  admin,
  user,
  guest
}

class OrientationService extends ChangeNotifier {
  static final OrientationService _instance = OrientationService._internal();
  
  factory OrientationService() => _instance;
  
  OrientationService._internal();

  bool _isInitialized = false;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;
  UserType _userType = UserType.guest;
  UserType? _trialUserType;
  bool _isTrialMode = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  UserType get userType => _userType;
  UserType? get trialUserType => _trialUserType;
  bool get isTrialMode => _isTrialMode;

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final userTypeStr = prefs.getString('user_type');
      _userType = userTypeStr != null 
          ? UserType.values.firstWhere(
              (type) => type.toString() == userTypeStr,
              orElse: () => UserType.guest)
          : UserType.guest;

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user type
  Future<void> updateUserType(UserType type) async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_type', type.toString());
      
      _userType = type;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Set error
  void setError(String error) {
    _error = error;
    notifyListeners();
  }

  // Set authenticated state
  void setAuthenticated(bool isAuthenticated) {
    _isLoggedIn = isAuthenticated;
    notifyListeners();
  }

  // Check if user is admin
  bool get isAdmin => _userType == UserType.admin;

  // Dispose
  @override
  void dispose() {
    _isInitialized = false;
    _isLoggedIn = false;
    _isLoading = false;
    _error = null;
    _userType = UserType.guest;
    _trialUserType = null;
    _isTrialMode = false;
    super.dispose();
  }
} 