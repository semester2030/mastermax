import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'data_migrator.dart';

class FirebaseDataTransfer {
  static const List<String> collections = [
    'users',
    'cars',
    'companies',
    'spotlight_videos',
    'video_shares',
    'subscriptions',
    'bank_transfers',
  ];

  static Future<void> initializeFirebaseApps() async {
    await Firebase.initializeApp(
      name: 'old_project',
      options: DataMigrator.migrationOldFirebaseOptions(),
    );
    await Firebase.initializeApp(
      name: 'new_project',
      options: DataMigrator.migrationNewFirebaseOptions(),
    );
  }

  static Future<void> transferData() async {
    try {
      final oldDB =
          FirebaseFirestore.instanceFor(app: Firebase.app('old_project'));
      final newDB =
          FirebaseFirestore.instanceFor(app: Firebase.app('new_project'));

      var totalTransferred = 0;

      for (final collection in collections) {
        debugPrint('FirebaseDataTransfer: $collection');
        final QuerySnapshot snapshot = await oldDB.collection(collection).get();

        for (final doc in snapshot.docs) {
          try {
            await newDB.collection(collection).doc(doc.id).set(
                  doc.data() as Map<String, dynamic>,
                );
            totalTransferred++;
          } catch (e) {
            debugPrint('FirebaseDataTransfer: doc ${doc.id} error: $e');
          }
        }
      }

      debugPrint('FirebaseDataTransfer: transferred $totalTransferred documents');
    } catch (e, st) {
      debugPrint('FirebaseDataTransfer failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> startTransfer() async {
    debugPrint('FirebaseDataTransfer: start (dart-define required, see DataMigrator)');
    await initializeFirebaseApps();
    await transferData();
  }
}
