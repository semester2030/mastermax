import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final _remoteConfig = FirebaseRemoteConfig.instance;
  bool _isInitialized = false;

  // المفاتيح المستخدمة في Remote Config
  static const String privacyPolicyKey = 'privacy_policy_content';
  static const String termsOfUseKey = 'terms_of_use_content';
  static const String intellectualPropertyKey = 'intellectual_property_content';
  static const String complaintsKey = 'complaints_content';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      await _remoteConfig.setDefaults({
        privacyPolicyKey: '',
        termsOfUseKey: '',
        intellectualPropertyKey: '',
        complaintsKey: '',
      });

      await _remoteConfig.fetchAndActivate();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing Remote Config: $e');
    }
  }

  String getPrivacyPolicy() {
    return _remoteConfig.getString(privacyPolicyKey);
  }

  String getTermsOfUse() {
    return _remoteConfig.getString(termsOfUseKey);
  }

  String getIntellectualProperty() {
    return _remoteConfig.getString(intellectualPropertyKey);
  }

  String getComplaints() {
    return _remoteConfig.getString(complaintsKey);
  }
} 