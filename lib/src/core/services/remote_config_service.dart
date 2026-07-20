import 'dart:async';

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

  /// Applies local defaults + last-activated cache, then starts a background fetch.
  /// Startup must not await the network fetch.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        // PR-014: MEP startup budget ≤ 5s (was 1 minute).
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      await _remoteConfig.setDefaults({
        privacyPolicyKey: '',
        termsOfUseKey: '',
        intellectualPropertyKey: '',
        complaintsKey: '',
      });

      // Local only: activate previously fetched/cached values if present.
      await _remoteConfig.activate();
      _isInitialized = true;

      unawaited(_fetchAndActivateInBackground());
    } catch (e) {
      debugPrint('Error initializing Remote Config: $e');
    }
  }

  Future<void> _fetchAndActivateInBackground() async {
    try {
      await _remoteConfig.fetch();
      await _remoteConfig.activate();
    } catch (e) {
      debugPrint('Error fetching Remote Config in background: $e');
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
