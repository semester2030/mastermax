import 'package:flutter/foundation.dart';
import 'user.dart';
import 'user_type.dart';

class AuthState extends ChangeNotifier {
  User? _user;
  String? _error;
  bool _isLoading = false;
  bool _isInitialized = false;
  UserType _userType = UserType.individual;
  bool _isTrialMode = true;

  User? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;
  UserType get userType => _userType;
  bool get isTrialMode => _isTrialMode;

  void initialize() {
    _isInitialized = true;
    notifyListeners();
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

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setUserType(UserType type) {
    _userType = type;
    notifyListeners();
  }

  void setTrialMode(bool isTrialMode) {
    _isTrialMode = isTrialMode;
    notifyListeners();
  }

  void logout() {
    _user = null;
    _error = null;
    notifyListeners();
  }
} 