import 'dart:convert';
import 'dart:html' as html;

void downloadAuditCsv(String filename, String csv) {
  final safeName = filename.replaceAll(RegExp(r'[^\w.\-]'), '_');
  final bytes = utf8.encode(csv);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', safeName.isEmpty ? 'audit.csv' : safeName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
