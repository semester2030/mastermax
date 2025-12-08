import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsTracker {
  static final AnalyticsTracker _instance = AnalyticsTracker._internal();
  factory AnalyticsTracker() => _instance;
  AnalyticsTracker._internal();

  late FirebaseAnalytics _analytics;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _analytics = FirebaseAnalytics.instance;
    _isInitialized = true;
  }

  Future<void> trackScreen(String screenName) async {
    if (!_isInitialized) await initialize();
    await _analytics.logScreenView(
      screenClass: screenName,
      screenName: screenName,
    );
  }

  Future<void> trackEvent(
    String name, {
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      final cleanParams = parameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      );

      await _analytics.logEvent(
        name: name,
        parameters: cleanParams,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to track event: $e');
      }
    }
  }

  Future<void> setUserId(String? userId) async {
    if (!_isInitialized) await initialize();
    await _analytics.setUserId(id: userId);
  }

  Future<void> setUserProperty({
    required String name,
    String? value,
  }) async {
    if (!_isInitialized) await initialize();
    await _analytics.setUserProperty(name: name, value: value);
  }

  Future<void> logLogin(String method) async {
    if (!_isInitialized) await initialize();
    await _analytics.logLogin(loginMethod: method);
  }

  Future<void> logSignUp(String method) async {
    if (!_isInitialized) await initialize();
    await _analytics.logSignUp(signUpMethod: method);
  }

  Future<void> logSearch(String searchTerm) async {
    if (!_isInitialized) await initialize();
    await _analytics.logSearch(searchTerm: searchTerm);
  }

  Future<void> logViewItem({
    required String itemId,
    required String itemName,
    required String itemCategory,
    double? price,
  }) async {
    if (!_isInitialized) await initialize();
    await _analytics.logViewItem(
      items: [
        AnalyticsEventItem(
          itemId: itemId,
          itemName: itemName,
          itemCategory: itemCategory,
          price: price,
        ),
      ],
    );
  }
} 