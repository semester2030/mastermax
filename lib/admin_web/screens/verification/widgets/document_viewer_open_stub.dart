import 'package:url_launcher/url_launcher.dart';

/// منصات غير الويب (أو بدون dart:html): فتح الرابط مباشرة.
Future<bool> openVerificationDocumentUrl(String url) async {
  final uri = Uri.parse(url);
  return launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
