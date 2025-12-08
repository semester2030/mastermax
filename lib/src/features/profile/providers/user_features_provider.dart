import 'package:flutter/material.dart';
import '../models/user_features.dart';
import '../services/user_features_service.dart';

class UserFeaturesProvider extends ChangeNotifier {
  final UserFeaturesService _service = UserFeaturesService();
  
  UserFeatures? _userFeatures;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserFeatures? get userFeatures => _userFeatures;
  bool get isLoading => _isLoading;
  String? get error => _error;
  UserType get userType => _userFeatures?.userType ?? UserType.individual;
  List<String> get features => _userFeatures?.features ?? [];
  Map<String, dynamic> get extraFields => _userFeatures?.extraFields ?? {};

  // تحميل مميزات المستخدم
  Future<void> loadUserFeatures(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userFeatures = await _service.getUserFeatures(userId);
      if (_userFeatures == null) {
        // إنشاء مميزات افتراضية للمستخدم الجديد
        await _service.updateUserType(userId, UserType.individual);
        _userFeatures = await _service.getUserFeatures(userId);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // تحديث نوع المستخدم
  Future<void> updateUserType(String userId, UserType newType) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.updateUserType(userId, newType);
      await loadUserFeatures(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // تحديث المميزات المخصصة
  Future<void> updateCustomFeatures(String userId, List<String> newFeatures) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.updateCustomFeatures(userId, newFeatures);
      await loadUserFeatures(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // تحديث الحقول الإضافية
  Future<void> updateExtraFields(String userId, Map<String, dynamic> fields) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.updateExtraFields(userId, fields);
      await loadUserFeatures(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // مراقبة تغييرات مميزات المستخدم
  void startWatchingFeatures(String userId) {
    _service.watchUserFeatures(userId).listen(
      (features) {
        _userFeatures = features;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  // التحقق من وجود ميزة معينة
  bool hasFeature(String feature) {
    return features.contains(feature);
  }

  // الحصول على المميزات المتاحة حسب نوع المستخدم
  List<String> getAvailableFeatures() {
    return UserTypeFeatures.getFeatures(userType);
  }

  @override
  void dispose() {
    // تنظيف الموارد إذا لزم الأمر
    super.dispose();
  }
} 