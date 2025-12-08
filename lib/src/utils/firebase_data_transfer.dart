import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDataTransfer {
  static const List<String> collections = [
    'users',
    'cars',
    'companies',
    'spotlight_videos',
    'video_shares',
    'subscriptions',
    'bank_transfers'
  ];

  static Future<void> initializeFirebaseApps() async {
    // Initialize old project (Master Max)
    await Firebase.initializeApp(
      name: 'old_project',
      options: const FirebaseOptions(
        apiKey: 'AIzaSyC799JbfYLQ5ka6t2rHYCNdTmwSD6TYiBU',
        appId: 'com.mastermax.app',
        messagingSenderId: '960074773700',
        projectId: 'master-max-ced03',
      ),
    );

    // Initialize new project (MasterMax-2030-Backend)
    await Firebase.initializeApp(
      name: 'new_project',
      options: const FirebaseOptions(
        apiKey: 'AIzaSyAd1TG_QdlI1EHSd-ZkptE94d3GVLbyBqw',
        appId: 'mastermax2030.app',
        messagingSenderId: '691078404023',
        projectId: 'mastermax-2030-backend',
      ),
    );
  }

  static Future<void> transferData() async {
    try {
      // Get instances for both databases
      final oldDB = FirebaseFirestore.instanceFor(app: Firebase.app('old_project'));
      final newDB = FirebaseFirestore.instanceFor(app: Firebase.app('new_project'));

      int totalTransferred = 0;

      // Transfer each collection
      for (String collection in collections) {
        print('📦 Transferring collection: $collection');
        
        // Get all documents from old collection
        final QuerySnapshot snapshot = await oldDB.collection(collection).get();
        
        // Transfer each document
        for (var doc in snapshot.docs) {
          try {
            await newDB.collection(collection).doc(doc.id).set(
              doc.data() as Map<String, dynamic>
            );
            totalTransferred++;
            print('✅ Transferred document ${doc.id} in $collection');
          } catch (e) {
            print('❌ Error transferring document ${doc.id} in $collection: $e');
          }
        }
        
        print('✅ Completed transferring $collection collection');
      }

      print('🎉 Successfully transferred $totalTransferred documents!');
    } catch (e) {
      print('❌ Error during transfer: $e');
      rethrow;
    }
  }

  static Future<void> startTransfer() async {
    try {
      print('🚀 Starting Firebase data transfer...');
      await initializeFirebaseApps();
      await transferData();
      print('✅ Data transfer completed successfully!');
    } catch (e) {
      print('❌ Failed to transfer data: $e');
      rethrow;
    }
  }
} 