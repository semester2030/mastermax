import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/logger.dart';

/// خدمة إدارة تقييمات وتعليقات العقارات
class PropertyReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// إضافة تقييم جديد
  Future<String> addReview({
    required String propertyId,
    required String userId,
    required String userName,
    required double rating,
    required String comment,
    List<String>? photos,
  }) async {
    try {
      // التحقق من أن المستخدم لم يقم بالتقييم من قبل
      final existingReview = await _firestore
          .collection('property_reviews')
          .where('propertyId', isEqualTo: propertyId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existingReview.docs.isNotEmpty) {
        throw Exception('لقد قمت بتقييم هذا العقار من قبل');
      }

      final review = await _firestore.collection('property_reviews').add({
        'propertyId': propertyId,
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'comment': comment,
        'photos': photos ?? [],
        'likes': 0,
        'dislikes': 0,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // تحديث متوسط التقييم في العقار
      await updatePropertyRating(propertyId);

      return review.id;
    } catch (e) {
      logError('Error adding review', e);
      rethrow;
    }
  }

  /// تحديث تقييم
  Future<void> updateReview({
    required String reviewId,
    double? rating,
    String? comment,
    List<String>? photos,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (rating != null) updates['rating'] = rating;
      if (comment != null) updates['comment'] = comment;
      if (photos != null) updates['photos'] = photos;

      final reviewDoc = await _firestore
          .collection('property_reviews')
          .doc(reviewId)
          .get();
      
      if (!reviewDoc.exists) {
        throw Exception('التقييم غير موجود');
      }

      await _firestore
          .collection('property_reviews')
          .doc(reviewId)
          .update(updates);

      // تحديث متوسط التقييم في العقار
      final String propertyId = reviewDoc.get('propertyId');
      await updatePropertyRating(propertyId);
    } catch (e) {
      logError('Error updating review', e);
      rethrow;
    }
  }

  /// حذف تقييم
  Future<void> deleteReview(String reviewId) async {
    try {
      final reviewDoc = await _firestore
          .collection('property_reviews')
          .doc(reviewId)
          .get();
      
      if (!reviewDoc.exists) {
        throw Exception('التقييم غير موجود');
      }

      final String propertyId = reviewDoc.get('propertyId');

      await _firestore.collection('property_reviews').doc(reviewId).delete();

      // تحديث متوسط التقييم في العقار
      await updatePropertyRating(propertyId);
    } catch (e) {
      logError('Error deleting review', e);
      rethrow;
    }
  }

  /// الحصول على تقييمات عقار معين
  Future<List<DocumentSnapshot>> getPropertyReviews(
    String propertyId, {
    String? sortBy,
    bool descending = true,
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection('property_reviews')
          .where('propertyId', isEqualTo: propertyId);

      if (sortBy != null) {
        query = query.orderBy(sortBy, descending: descending);
      } else {
        query = query.orderBy('createdAt', descending: true);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final QuerySnapshot result = await query.get();
      return result.docs;
    } catch (e) {
      logError('Error getting property reviews', e);
      rethrow;
    }
  }

  /// تحديث متوسط التقييم في العقار
  Future<void> updatePropertyRating(String propertyId) async {
    try {
      final QuerySnapshot reviews = await _firestore
          .collection('property_reviews')
          .where('propertyId', isEqualTo: propertyId)
          .get();

      if (reviews.docs.isEmpty) {
        await _firestore.collection('properties').doc(propertyId).update({
          'rating': 0.0,
          'reviewsCount': 0,
        });
        return;
      }

      double totalRating = 0;
      for (final review in reviews.docs) {
        totalRating += review.get('rating') as double;
      }

      final double averageRating = totalRating / reviews.docs.length;

      await _firestore.collection('properties').doc(propertyId).update({
        'rating': averageRating,
        'reviewsCount': reviews.docs.length,
      });
    } catch (e) {
      logError('Error updating property rating', e);
      rethrow;
    }
  }

  /// إضافة رد على تقييم
  Future<String> addReviewReply({
    required String reviewId,
    required String userId,
    required String userName,
    required String reply,
  }) async {
    try {
      final replyDoc = await _firestore
          .collection('property_reviews')
          .doc(reviewId)
          .collection('replies')
          .add({
        'userId': userId,
        'userName': userName,
        'reply': reply,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return replyDoc.id;
    } catch (e) {
      logError('Error adding review reply', e);
      rethrow;
    }
  }

  /// الإعجاب/عدم الإعجاب بتقييم
  Future<void> updateReviewReaction({
    required String reviewId,
    required String userId,
    required bool isLike,
  }) async {
    try {
      final reviewRef = _firestore.collection('property_reviews').doc(reviewId);
      final userReactionRef = reviewRef.collection('reactions').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userReactionDoc = await transaction.get(userReactionRef);
        final reviewDoc = await transaction.get(reviewRef);

        if (!reviewDoc.exists) {
          throw Exception('التقييم غير موجود');
        }

        final bool hasExistingReaction = userReactionDoc.exists;
        final bool? existingIsLike = hasExistingReaction
            ? userReactionDoc.get('isLike') as bool
            : null;

        // تحديث عدد الإعجابات وعدم الإعجابات
        final int currentLikes = reviewDoc.get('likes') as int;
        final int currentDislikes = reviewDoc.get('dislikes') as int;

        if (!hasExistingReaction) {
          // إضافة تفاعل جديد
          transaction.set(userReactionRef, {
            'isLike': isLike,
            'createdAt': FieldValue.serverTimestamp(),
          });

          transaction.update(reviewRef, {
            if (isLike) 'likes': currentLikes + 1,
            if (!isLike) 'dislikes': currentDislikes + 1,
          });
        } else if (existingIsLike != isLike) {
          // تغيير نوع التفاعل
          transaction.update(userReactionRef, {
            'isLike': isLike,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          transaction.update(reviewRef, {
            'likes': isLike ? currentLikes + 1 : currentLikes - 1,
            'dislikes': isLike ? currentDislikes - 1 : currentDislikes + 1,
          });
        }
      });
    } catch (e) {
      logError('Error updating review reaction', e);
      rethrow;
    }
  }

  /// الحصول على إحصائيات التقييمات
  Future<Map<String, dynamic>> getReviewStatistics(String propertyId) async {
    try {
      final QuerySnapshot reviews = await _firestore
          .collection('property_reviews')
          .where('propertyId', isEqualTo: propertyId)
          .get();

      final Map<int, int> ratingDistribution = {
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
      };

      final int totalReviews = reviews.docs.length;
      double totalRating = 0;
      int verifiedReviews = 0;
      int reviewsWithPhotos = 0;

      for (final review in reviews.docs) {
        final double rating = review.get('rating') as double;
        final bool isVerified = review.get('isVerified') as bool;
        final List<String> photos = List<String>.from(review.get('photos') ?? []);

        totalRating += rating;
        ratingDistribution[rating.round()] =
            (ratingDistribution[rating.round()] ?? 0) + 1;
        
        if (isVerified) verifiedReviews++;
        if (photos.isNotEmpty) reviewsWithPhotos++;
      }

      return {
        'averageRating': totalReviews > 0 ? totalRating / totalReviews : 0,
        'totalReviews': totalReviews,
        'verifiedReviews': verifiedReviews,
        'reviewsWithPhotos': reviewsWithPhotos,
        'ratingDistribution': ratingDistribution,
      };
    } catch (e) {
      logError('Error getting review statistics', e);
      rethrow;
    }
  }
} 