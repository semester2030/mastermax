import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/logger.dart';

/// خدمة مشاركة العقارات
class PropertySharingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// إنشاء رابط مشاركة للعقار
  Future<String> createShareLink(String propertyId) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      // يمكن استخدام Firebase Dynamic Links هنا لإنشاء روابط ديناميكية
      const String baseUrl = 'https://yourapp.com/property';
      final String shareLink = '$baseUrl/$propertyId';

      // تسجيل المشاركة
      await _firestore.collection('property_shares').add({
        'propertyId': propertyId,
        'shareLink': shareLink,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return shareLink;
    } catch (e) {
      logError('Error creating share link', e);
      rethrow;
    }
  }

  /// مشاركة العقار
  Future<void> shareProperty(String propertyId) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      final String title = propertyDoc.get('title');
      final double price = propertyDoc.get('price');
      final String address = propertyDoc.get('address');
      final String shareLink = await createShareLink(propertyId);

      final String shareText = '''
🏠 $title
💰 $price
📍 $address

للمزيد من التفاصيل:
$shareLink
''';

      await Share.share(shareText, subject: title);

      // تسجيل إحصائيات المشاركة
      await _firestore.collection('properties').doc(propertyId).update({
        'shareCount': FieldValue.increment(1),
      });
    } catch (e) {
      logError('Error sharing property', e);
      rethrow;
    }
  }

  /// مشاركة عبر WhatsApp
  Future<void> shareViaWhatsApp(String propertyId) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      final String title = propertyDoc.get('title');
      final double price = propertyDoc.get('price');
      final String shareLink = await createShareLink(propertyId);

      final String message = '''
*$title*
السعر: $price
للمزيد من التفاصيل: $shareLink
''';

      final Uri whatsappUrl = Uri.parse(
        'whatsapp://send?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else {
        throw Exception('لا يمكن فتح WhatsApp');
      }

      // تسجيل المشاركة
      await _firestore.collection('property_shares').add({
        'propertyId': propertyId,
        'platform': 'whatsapp',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Error sharing via WhatsApp', e);
      rethrow;
    }
  }

  /// إنشاء صورة قابلة للمشاركة
  Future<String> createShareableImage(String propertyId) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      // هنا يمكن إضافة منطق لإنشاء صورة جذابة للعقار
      // يمكن استخدام مكتبات مثل flutter_canvas أو screenshot

      // مثال بسيط: إرجاع رابط الصورة الرئيسية
      final List<String> images = List<String>.from(propertyDoc.get('images'));
      if (images.isNotEmpty) {
        return images.first;
      }

      throw Exception('لا توجد صور للعقار');
    } catch (e) {
      logError('Error creating shareable image', e);
      rethrow;
    }
  }

  /// مشاركة عبر البريد الإلكتروني
  Future<void> shareViaEmail(
    String propertyId,
    String recipientEmail, {
    String? subject,
    String? additionalMessage,
  }) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      final String title = propertyDoc.get('title');
      final double price = propertyDoc.get('price');
      final String address = propertyDoc.get('address');
      final String shareLink = await createShareLink(propertyId);

      final String emailSubject = subject ?? 'عقار للمشاركة: $title';
      final String emailBody = '''
مرحباً،

أود مشاركة هذا العقار معك:

$title
السعر: $price
العنوان: $address

${additionalMessage ?? ''}

للمزيد من التفاصيل:
$shareLink

مع تحياتي،
''';

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: recipientEmail,
        query: encodeQueryParameters({
          'subject': emailSubject,
          'body': emailBody,
        }),
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw Exception('لا يمكن فتح تطبيق البريد الإلكتروني');
      }

      // تسجيل المشاركة
      await _firestore.collection('property_shares').add({
        'propertyId': propertyId,
        'platform': 'email',
        'recipientEmail': recipientEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Error sharing via email', e);
      rethrow;
    }
  }

  /// مشاركة عبر الرسائل القصيرة
  Future<void> shareViaSMS(String propertyId, String phoneNumber) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      
      if (!propertyDoc.exists) {
        throw Exception('العقار غير موجود');
      }

      final String title = propertyDoc.get('title');
      final double price = propertyDoc.get('price');
      final String shareLink = await createShareLink(propertyId);

      final String message = '''
$title
السعر: $price
للتفاصيل: $shareLink
''';

      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        throw Exception('لا يمكن فتح تطبيق الرسائل');
      }

      // تسجيل المشاركة
      await _firestore.collection('property_shares').add({
        'propertyId': propertyId,
        'platform': 'sms',
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Error sharing via SMS', e);
      rethrow;
    }
  }

  /// الحصول على إحصائيات المشاركة
  Future<Map<String, dynamic>> getShareStatistics(String propertyId) async {
    try {
      final QuerySnapshot shares = await _firestore
          .collection('property_shares')
          .where('propertyId', isEqualTo: propertyId)
          .get();

      final Map<String, int> platformStats = {};
      final List<DateTime> shareDates = [];

      for (final share in shares.docs) {
        final String platform = share.get('platform') ?? 'other';
        platformStats[platform] = (platformStats[platform] ?? 0) + 1;

        final Timestamp timestamp = share.get('createdAt') as Timestamp;
        shareDates.add(timestamp.toDate());
      }

      return {
        'totalShares': shares.docs.length,
        'platformStats': platformStats,
        'shareDates': shareDates,
      };
    } catch (e) {
      logError('Error getting share statistics', e);
      rethrow;
    }
  }

  /// مساعد لترميز معلمات الاستعلام
  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
} 