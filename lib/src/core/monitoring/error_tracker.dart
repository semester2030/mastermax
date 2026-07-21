import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Production-safe error reporting abstraction (Crashlytics when available).
///
/// Does not attach PII or application state automatically. Callers must pass
/// only safe context in [recordError] / [log] / [setCustomKey].
class ErrorTracker {
  static final ErrorTracker _instance = ErrorTracker._internal();
  factory ErrorTracker() => _instance;
  ErrorTracker._internal();

  FirebaseCrashlytics? _crashlytics;
  bool _isInitialized = false;
  bool _handlersInstalled = false;

  /// Initialize after Firebase is ready. Safe if Crashlytics is unavailable.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (!kIsWeb) {
        _crashlytics = FirebaseCrashlytics.instance;
        await _crashlytics!.setCrashlyticsCollectionEnabled(kReleaseMode);
      }
    } catch (e, st) {
      debugPrint('ErrorTracker Crashlytics setup failed: $e\n$st');
      _crashlytics = null;
    }

    try {
      _installGlobalHandlers();
    } catch (e, st) {
      debugPrint('ErrorTracker handler install failed: $e\n$st');
    }

    _isInitialized = true;
  }

  void _installGlobalHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    FlutterError.onError = (FlutterErrorDetails details) {
      // Always preserve Flutter diagnostics (debug + release console).
      FlutterError.presentError(details);
      if (kReleaseMode) {
        try {
          final crashlytics = _crashlytics;
          if (crashlytics != null) {
            crashlytics.recordFlutterError(details);
          }
        } catch (e) {
          debugPrint('ErrorTracker.recordFlutterError failed: $e');
        }
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      unawaited(recordError(error, stack, fatal: true, printDetails: kDebugMode));
      return true;
    };
  }

  Future<void> setUserIdentifier(String userId) async {
    if (!_isInitialized) await initialize();
    try {
      await _crashlytics?.setUserIdentifier(userId);
    } catch (e) {
      debugPrint('ErrorTracker.setUserIdentifier failed: $e');
    }
  }

  Future<void> log(String message) async {
    if (!_isInitialized) await initialize();
    try {
      await _crashlytics?.log(message);
    } catch (e) {
      debugPrint('ErrorTracker.log failed: $e');
    }
  }

  Future<void> recordError(
    dynamic error,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object>? information,
    bool? printDetails,
    bool fatal = false,
  }) async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (_) {
        // Never throw back into callers / zone.
      }
    }

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

    try {
      final crashlytics = _crashlytics;
      if (crashlytics == null) return;
      await crashlytics.recordError(
        error,
        stack,
        reason: reason,
        information: information?.toList() ?? const <Object>[],
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('ErrorTracker.recordError failed: $e');
    }
  }

  Future<void> recordFlutterError(FlutterErrorDetails flutterErrorDetails) async {
    if (!_isInitialized) await initialize();
    try {
      await _crashlytics?.recordFlutterError(flutterErrorDetails);
    } catch (e) {
      debugPrint('ErrorTracker.recordFlutterError failed: $e');
    }
  }

  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_isInitialized) await initialize();
    try {
      final crashlytics = _crashlytics;
      if (crashlytics == null) return;
      if (value is String) {
        await crashlytics.setCustomKey(key, value);
      } else if (value is bool) {
        await crashlytics.setCustomKey(key, value);
      } else if (value is int) {
        await crashlytics.setCustomKey(key, value);
      } else if (value is double) {
        await crashlytics.setCustomKey(key, value);
      } else {
        await crashlytics.setCustomKey(key, value.toString());
      }
    } catch (e) {
      debugPrint('ErrorTracker.setCustomKey failed: $e');
    }
  }

  Future<void> setCustomKeys(Map<String, dynamic> keys) async {
    if (!_isInitialized) await initialize();
    for (final entry in keys.entries) {
      await setCustomKey(entry.key, entry.value);
    }
  }

  /// Debug-only local verification helper (already present; not for production).
  Future<void> crash() async {
    if (kDebugMode) {
      debugPrint('Forcing a crash for testing...');
      throw Exception('Forced crash for testing Crashlytics');
    }
  }
}
