// PR-029 — Staging FirebaseOptions for project `mastermax-2030-staging`.
// Generated from official Firebase CLI `apps:sdkconfig` (not invented).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'firebase_options.dart';
import 'src/core/config/app_config.dart';

/// Staging [FirebaseOptions] for `mastermax-2030-staging`.
class StagingFirebaseOptions {
  static const String projectId = 'mastermax-2030-staging';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        // No dedicated macOS staging app registered in PR-029.
        throw UnsupportedError(
          'StagingFirebaseOptions have not been configured for macOS. '
          'Build without USE_STAGING or register a staging macOS app.',
        );
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'StagingFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'StagingFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDkTwmAGy9n4PNDsxY2c4L49XfXRvA0qfU',
    appId: '1:978010449165:web:ad4a3992f165febe0bbc44',
    messagingSenderId: '978010449165',
    projectId: projectId,
    authDomain: 'mastermax-2030-staging.firebaseapp.com',
    storageBucket: 'mastermax-2030-staging.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCLthWFaDpOlBmXxv98JOMZPuMulE1Ehc0',
    appId: '1:978010449165:android:367a0ca179bb23350bbc44',
    messagingSenderId: '978010449165',
    projectId: projectId,
    storageBucket: 'mastermax-2030-staging.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAgIpS7oUPOrEnQCpF9eQokDmXHePgWINQ',
    appId: '1:978010449165:ios:bf79466634bb11080bbc44',
    messagingSenderId: '978010449165',
    projectId: projectId,
    storageBucket: 'mastermax-2030-staging.firebasestorage.app',
    iosBundleId: 'com.darcar.app',
  );
}

/// Central Firebase options selection (PR-029).
///
/// `USE_STAGING=false` (default) → production [DefaultFirebaseOptions].
/// `USE_STAGING=true` → [StagingFirebaseOptions] only (no prod fallback).
class AppFirebaseOptions {
  static const String productionProjectId = 'mastermax-2030-backend';
  static const String stagingProjectId = StagingFirebaseOptions.projectId;

  static FirebaseOptions get currentPlatform {
    final options = AppConfig.useStaging
        ? StagingFirebaseOptions.currentPlatform
        : DefaultFirebaseOptions.currentPlatform;
    _validateAndLog(options);
    return options;
  }

  static FirebaseOptions get web {
    final options = AppConfig.useStaging
        ? StagingFirebaseOptions.web
        : DefaultFirebaseOptions.web;
    _validateAndLog(options);
    return options;
  }

  static void _validateAndLog(FirebaseOptions options) {
    if (AppConfig.useStaging) {
      if (options.projectId.isEmpty) {
        throw StateError(
          'USE_STAGING=true but staging FirebaseOptions.projectId is empty. '
          'Refusing to fall back to production.',
        );
      }
      if (options.projectId == productionProjectId) {
        throw StateError(
          'USE_STAGING=true resolved to production project '
          '`$productionProjectId`. Refusing silent production fallback.',
        );
      }
      if (options.projectId != stagingProjectId) {
        throw StateError(
          'USE_STAGING=true but projectId=`${options.projectId}` '
          '(expected `$stagingProjectId`).',
        );
      }
    }

    assert(() {
      debugPrint(
        '[FirebaseEnv] USE_STAGING=${AppConfig.useStaging} '
        'projectId=${options.projectId}',
      );
      return true;
    }());
  }
}
