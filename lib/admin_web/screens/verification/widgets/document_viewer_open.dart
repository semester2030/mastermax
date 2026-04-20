import 'document_viewer_open_stub.dart'
    if (dart.library.html) 'document_viewer_open_web.dart' as opener;

Future<bool> openVerificationDocumentUrl(String url) {
  final t = url.trim();
  if (t.isEmpty) return Future.value(false);
  return opener.openVerificationDocumentUrl(t);
}
