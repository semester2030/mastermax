import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

/// خدمة حفظ تاريخ مشاهدة الفيديوهات
class VideoHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();
  
  static const String _collection = 'user_video_history';
  static const int _maxHistoryItems = 150; // ✅ الحد الأقصى: 150 سجل

  /// حفظ فيديو في تاريخ المشاهدة
  /// 
  /// [videoId]: معرف الفيديو
  /// [videoTitle]: عنوان الفيديو (للعرض السريع)
  Future<void> addToHistory(String videoId, String videoTitle) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _logger.w('User not authenticated, skipping history save');
        return;
      }

      final userId = user.uid;
      final historyRef = _firestore
          .collection(_collection)
          .doc(userId)
          .collection('videos')
          .doc(videoId);

      // التحقق من وجود السجل
      final existingDoc = await historyRef.get();
      
      if (existingDoc.exists) {
        // تحديث وقت المشاهدة فقط
        await historyRef.update({
          'watchedAt': FieldValue.serverTimestamp(),
        });
        _logger.d('✅ Updated video history: $videoId');
      } else {
        // إضافة سجل جديد
        await historyRef.set({
          'videoId': videoId,
          'videoTitle': videoTitle,
          'watchedAt': FieldValue.serverTimestamp(),
        });
        _logger.d('✅ Added video to history: $videoId');
        
        // ✅ التحقق من الحد الأقصى وحذف الأقدم إذا لزم
        await _enforceMaxHistoryLimit(userId);
      }
    } catch (e) {
      _logger.e('❌ Error adding video to history: $e');
      // لا نرمي الخطأ - هذا ليس حرجاً
    }
  }

  /// فرض الحد الأقصى لسجلات التاريخ (حذف الأقدم تلقائياً)
  Future<void> _enforceMaxHistoryLimit(String userId) async {
    try {
      final historyRef = _firestore
          .collection(_collection)
          .doc(userId)
          .collection('videos');

      // جلب جميع السجلات مرتبة حسب التاريخ (الأقدم أولاً)
      final snapshot = await historyRef
          .orderBy('watchedAt', descending: false)
          .get();

      final totalCount = snapshot.docs.length;

      // إذا تجاوزنا الحد الأقصى، نحذف الأقدم
      if (totalCount > _maxHistoryItems) {
        final itemsToDelete = totalCount - _maxHistoryItems;
        final batch = _firestore.batch();

        for (int i = 0; i < itemsToDelete; i++) {
          batch.delete(snapshot.docs[i].reference);
        }

        await batch.commit();
        _logger.d('✅ Deleted $itemsToDelete old history items');
      }
    } catch (e) {
      _logger.e('❌ Error enforcing history limit: $e');
      // لا نرمي الخطأ - هذا ليس حرجاً
    }
  }

  /// جلب تاريخ المشاهدة للمستخدم
  /// 
  /// [limit]: الحد الأقصى لعدد السجلات (افتراضي: 150)
  Future<List<VideoHistoryItem>> getHistory({int limit = 150}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      final userId = user.uid;
      final snapshot = await _firestore
          .collection(_collection)
          .doc(userId)
          .collection('videos')
          .orderBy('watchedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return VideoHistoryItem(
          videoId: data['videoId'] as String? ?? doc.id,
          videoTitle: data['videoTitle'] as String? ?? 'بدون عنوان',
          watchedAt: (data['watchedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      _logger.e('❌ Error getting video history: $e');
      return [];
    }
  }

  /// حذف فيديو من تاريخ المشاهدة
  Future<bool> removeFromHistory(String videoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      final userId = user.uid;
      await _firestore
          .collection(_collection)
          .doc(userId)
          .collection('videos')
          .doc(videoId)
          .delete();

      _logger.d('✅ Removed video from history: $videoId');
      return true;
    } catch (e) {
      _logger.e('❌ Error removing video from history: $e');
      return false;
    }
  }

  /// حذف جميع سجلات التاريخ
  Future<bool> clearHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      final userId = user.uid;
      final snapshot = await _firestore
          .collection(_collection)
          .doc(userId)
          .collection('videos')
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _logger.d('✅ Cleared all video history');
      return true;
    } catch (e) {
      _logger.e('❌ Error clearing video history: $e');
      return false;
    }
  }

  /// جلب عدد سجلات التاريخ
  Future<int> getHistoryCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 0;
      }

      final userId = user.uid;
      final snapshot = await _firestore
          .collection(_collection)
          .doc(userId)
          .collection('videos')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      _logger.e('❌ Error getting history count: $e');
      return 0;
    }
  }
}

/// نموذج بيانات سجل تاريخ المشاهدة
class VideoHistoryItem {
  final String videoId;
  final String videoTitle;
  final DateTime watchedAt;

  VideoHistoryItem({
    required this.videoId,
    required this.videoTitle,
    required this.watchedAt,
  });
}
