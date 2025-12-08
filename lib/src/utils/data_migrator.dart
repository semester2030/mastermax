import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DataMigrator {
  static Future<void> migrateData() async {
    try {
      print('🚀 بدء تهيئة Firebase...');
      
      // تهيئة Firebase للمشروع القديم
      final FirebaseApp oldApp = await Firebase.initializeApp(
        name: 'old_project',
        options: const FirebaseOptions(
          apiKey: 'AIzaSyC799JbfYLQ5ka6t2rHYCNdTmwSD6TYiBU',
          appId: '1:960074773700:android:1234567890',
          messagingSenderId: '960074773700',
          projectId: 'master-max-ced03',
          storageBucket: 'master-max-ced03.appspot.com',
        ),
      );
      print('✅ تم تهيئة المشروع القديم');

      // تسجيل الدخول في المشروع القديم
      final oldAuth = FirebaseAuth.instanceFor(app: oldApp);
      await oldAuth.signInWithEmailAndPassword(
        email: 'admin@mastermax.com',
        password: 'admin123456'  // تأكد من استخدام كلمة المرور الصحيحة
      );
      print('✅ تم تسجيل الدخول في المشروع القديم');

      // قراءة البيانات من المشروع القديم
      final oldDb = FirebaseFirestore.instanceFor(app: oldApp);
      
      // تهيئة Firebase للمشروع الجديد
      final FirebaseApp newApp = await Firebase.initializeApp(
        name: 'new_project',
        options: const FirebaseOptions(
          apiKey: 'AIzaSyAd1TG_QdlI1EHSd-ZkptE94d3GVLbyBqw',
          appId: '1:691078404023:android:3cfb1da3e6b5ca5068ba32',
          messagingSenderId: '691078404023',
          projectId: 'mastermax-2030-backend',
          storageBucket: 'mastermax-2030-backend.appspot.com',
        ),
      );
      print('✅ تم تهيئة المشروع الجديد');

      // تسجيل الدخول في المشروع الجديد
      final newAuth = FirebaseAuth.instanceFor(app: newApp);
      await newAuth.signInWithEmailAndPassword(
        email: 'admin@mastermax.com',
        password: 'admin123456'  // تأكد من استخدام كلمة المرور الصحيحة
      );
      print('✅ تم تسجيل الدخول في المشروع الجديد');

      final newDb = FirebaseFirestore.instanceFor(app: newApp);
      int totalDocuments = 0;

      // قائمة المجموعات المراد نقلها
      final collections = [
        'users',
        'cars',
        'companies',
        'spotlight_videos',
        'video_shares',
        'subscriptions',
        'bank_transfers'
      ];

      // نقل البيانات
      for (final collection in collections) {
        print('📦 جاري نقل مجموعة: $collection');
        
        try {
          // قراءة البيانات من المشروع القديم
          final QuerySnapshot snapshot = await oldDb.collection(collection).get();
          print('📥 تم العثور على ${snapshot.docs.length} مستند في $collection');
          
          if (snapshot.docs.isEmpty) {
            print('⚠️ المجموعة $collection فارغة');
            continue;
          }

          // نقل كل مستند
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              await newDb.collection(collection).doc(doc.id).set(data);
              totalDocuments++;
              print('✅ تم نقل المستند ${doc.id} في $collection');
            } catch (e) {
              print('❌ خطأ في نقل المستند ${doc.id}: $e');
            }
          }
          
          print('✅ تم نقل مجموعة $collection بنجاح');
        } catch (e) {
          print('❌ خطأ في نقل مجموعة $collection: $e');
        }
      }

      print('🎉 تم نقل $totalDocuments مستند بنجاح!');

      // تسجيل الخروج من كلا المشروعين
      await oldAuth.signOut();
      await newAuth.signOut();
      
    } catch (e) {
      print('❌ حدث خطأ أثناء عملية النقل: $e');
      rethrow;
    }
  }
} 