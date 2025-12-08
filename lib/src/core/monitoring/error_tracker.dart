import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class ErrorTracker {
  static final ErrorTracker _instance = ErrorTracker._internal();
  factory ErrorTracker() => _instance;
  ErrorTracker._internal();

  late FirebaseCrashlytics _crashlytics;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _crashlytics = FirebaseCrashlytics.instance;
    await _crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);
    
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kReleaseMode) {
        _crashlytics.recordFlutterError(details);
      } else {
        FlutterError.dumpErrorToConsole(details);
      }
    };

    _isInitialized = true;
  }

  Future<void> setUserIdentifier(String userId) async {
    if (!_isInitialized) await initialize();
    await _crashlytics.setUserIdentifier(userId);
  }

  Future<void> log(String message) async {
    if (!_isInitialized) await initialize();
    await _crashlytics.log(message);
  }

  Future<void> recordError(dynamic error, StackTrace? stack, {
    dynamic reason,
    Iterable<Object>? information,
    bool? printDetails,
    bool fatal = false,
  }) async {
    if (!_isInitialized) await initialize();

    if (kDebugMode && (printDetails ?? true)) {
      debugPrint('Error: $error');
      if (reason != null) debugPrint('Reason: $reason');
      if (stack != null) debugPrint('Stack trace: $stack');
      if (information != null) {
        debugPrint('Additional information:');
        for (final info in information) {
          debugPrint(info.toString());
        }
      }
    }

    await _crashlytics.recordError(
      error,
      stack,
      reason: reason,
      information: information?.toList() ?? [],
      fatal: fatal,
    );
  }

  Future<void> recordFlutterError(FlutterErrorDetails flutterErrorDetails) async {
    if (!_isInitialized) await initialize();
    await _crashlytics.recordFlutterError(flutterErrorDetails);
  }

  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_isInitialized) await initialize();
    
    if (value is String) {
      await _crashlytics.setCustomKey(key, value);
    } else if (value is bool) {
      await _crashlytics.setCustomKey(key, value);
    } else if (value is int) {
      await _crashlytics.setCustomKey(key, value);
    } else if (value is double) {
      await _crashlytics.setCustomKey(key, value);
    } else {
      await _crashlytics.setCustomKey(key, value.toString());
    }
  }

  Future<void> setCustomKeys(Map<String, dynamic> keys) async {
    if (!_isInitialized) await initialize();
    for (final entry in keys.entries) {
      await setCustomKey(entry.key, entry.value);
    }
  }

  Future<void> crash() async {
    if (kDebugMode) {
      debugPrint('Forcing a crash for testing...');
      throw Exception('Forced crash for testing Crashlytics');
    }
  }
} 