// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

/// على الويب: جلب الملف بجلسة Firebase Auth ثم فتحه كـ Blob (يتجاوز 403 عند فتح الرابط خام).
Future<bool> openVerificationDocumentUrl(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;

  final isFirebaseStorage = trimmed.contains('firebasestorage.googleapis.com') ||
      trimmed.startsWith('gs://');

  if (isFirebaseStorage) {
    try {
      final ref = FirebaseStorage.instance.refFromURL(trimmed);
      final data = await ref.getData(40 * 1024 * 1024);
      if (data == null || data.isEmpty) return false;

      final blob = html.Blob([data], 'application/pdf');
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(blobUrl, '_blank');
      Future<void>.delayed(const Duration(seconds: 90), () {
        html.Url.revokeObjectUrl(blobUrl);
      });
      return true;
    } catch (_) {
      // إن فشل التحميل بالمسار الرسمي، نجرّب فتح الرابط كما هو
    }
  }

  final uri = Uri.parse(trimmed);
  return launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
