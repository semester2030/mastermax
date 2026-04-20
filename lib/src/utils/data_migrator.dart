import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// أداة هجرة بين مشروعي Firebase. لا تُضمَّن أسرار في الكود.
///
/// شغّل مع `--dart-define` لكل المتغيرات المطلوبة (انظر [_readOptions] و[_readCredentials]).
class DataMigrator {
  /// خيارات مشروع المصدر (من `--dart-define=MIGRATE_OLD_FIREBASE_*`).
  static FirebaseOptions migrationOldFirebaseOptions() =>
      _firebaseOptionsFromDefines('MIGRATE_OLD_FIREBASE');

  /// خيارات مشروع الوجهة (من `--dart-define=MIGRATE_NEW_FIREBASE_*`).
  static FirebaseOptions migrationNewFirebaseOptions() =>
      _firebaseOptionsFromDefines('MIGRATE_NEW_FIREBASE');

  static FirebaseOptions _firebaseOptionsFromDefines(String prefix) {
    String v(String suffix) => String.fromEnvironment(
          '${prefix}_$suffix',
          defaultValue: '',
        );
    final apiKey = v('API_KEY');
    final appId = v('APP_ID');
    final messagingSenderId = v('MESSAGING_SENDER_ID');
    final projectId = v('PROJECT_ID');
    final storageBucket = v('STORAGE_BUCKET');
    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty) {
      throw StateError(
        'Missing dart-define for $prefix: need API_KEY, APP_ID, '
        'MESSAGING_SENDER_ID, PROJECT_ID (and optionally STORAGE_BUCKET).',
      );
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? '$projectId.appspot.com' : storageBucket,
    );
  }

  static ({String email, String password}) _credentials() {
    const email = String.fromEnvironment('MIGRATE_EMAIL', defaultValue: '');
    const password =
        String.fromEnvironment('MIGRATE_PASSWORD', defaultValue: '');
    if (email.isEmpty || password.isEmpty) {
      throw StateError(
        'Set MIGRATE_EMAIL and MIGRATE_PASSWORD via --dart-define (do not commit).',
      );
    }
    return (email: email, password: password);
  }

  static Future<void> migrateData() async {
    try {
      debugPrint('DataMigrator: starting (secrets from dart-define only)…');

      final creds = _credentials();
      final oldOptions = migrationOldFirebaseOptions();
      final newOptions = migrationNewFirebaseOptions();

      final FirebaseApp oldApp = await Firebase.initializeApp(
        name: 'old_project',
        options: oldOptions,
      );
      final oldAuth = FirebaseAuth.instanceFor(app: oldApp);
      await oldAuth.signInWithEmailAndPassword(
        email: creds.email,
        password: creds.password,
      );

      final oldDb = FirebaseFirestore.instanceFor(app: oldApp);

      final FirebaseApp newApp = await Firebase.initializeApp(
        name: 'new_project',
        options: newOptions,
      );
      final newAuth = FirebaseAuth.instanceFor(app: newApp);
      await newAuth.signInWithEmailAndPassword(
        email: creds.email,
        password: creds.password,
      );

      final newDb = FirebaseFirestore.instanceFor(app: newApp);
      var totalDocuments = 0;

      const collections = [
        'users',
        'cars',
        'companies',
        'spotlight_videos',
        'video_shares',
        'subscriptions',
        'bank_transfers',
      ];

      for (final collection in collections) {
        debugPrint('DataMigrator: collection $collection');
        try {
          final QuerySnapshot snapshot =
              await oldDb.collection(collection).get();
          if (snapshot.docs.isEmpty) {
            debugPrint('DataMigrator: $collection empty, skip');
            continue;
          }
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              await newDb.collection(collection).doc(doc.id).set(data);
              totalDocuments++;
            } catch (e) {
              debugPrint('DataMigrator: doc ${doc.id} error: $e');
            }
          }
        } catch (e) {
          debugPrint('DataMigrator: collection $collection error: $e');
        }
      }

      debugPrint('DataMigrator: done, $totalDocuments documents');
      await oldAuth.signOut();
      await newAuth.signOut();
    } catch (e, st) {
      debugPrint('DataMigrator failed: $e\n$st');
      rethrow;
    }
  }
}
