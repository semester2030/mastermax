// تشغيل من جذر المشروع: dart run tool/strip_logo_black_background.dart
// اختياري: يزيل خلفية داكنة من JPEG ويكتب dar_car_logo.png (إن وُجد JPEG قديم).
import 'dart:io';

import 'package:image/image.dart' as img;

/// سطوع تقريبي 0–255
double _luma(img.Pixel p) {
  return 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
}

/// إزالة كل البكسل «الداكنة جداً» (خلفية سوداء + مضاد التعرّج).
void _keyDarkPixels(img.Image im, {required int rgbMax, required double lumaMax}) {
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      final p = im.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final lum = _luma(p);
      if (r < rgbMax && g < rgbMax && b < rgbMax && lum < lumaMax) {
        im.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
}

/// إزالة المناطق الداكنة المتصلة بحدود الصورة (شريط أسود يصل للحافة).
void _floodClearFromEdges(img.Image im, {required double edgeEnter, required double spreadMax}) {
  final w = im.width;
  final h = im.height;
  final vis = List.generate(h, (_) => List<bool>.filled(w, false));
  final q = <List<int>>[];

  bool darkEnough(int x, int y, double maxL) => _luma(im.getPixel(x, y)) < maxL;

  void tryPush(int x, int y, double gate) {
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    if (vis[y][x]) return;
    if (!darkEnough(x, y, gate)) return;
    vis[y][x] = true;
    q.add([x, y]);
  }

  for (var x = 0; x < w; x++) {
    tryPush(x, 0, edgeEnter);
    tryPush(x, h - 1, edgeEnter);
  }
  for (var y = 0; y < h; y++) {
    tryPush(0, y, edgeEnter);
    tryPush(w - 1, y, edgeEnter);
  }

  var qi = 0;
  while (qi < q.length) {
    final c = q[qi++];
    final x = c[0];
    final y = c[1];
    im.setPixelRgba(x, y, 0, 0, 0, 0);
    for (final d in const [[0, 1], [0, -1], [1, 0], [-1, 0]]) {
      final nx = x + d[0];
      final ny = y + d[1];
      if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
      if (vis[ny][nx]) continue;
      if (!darkEnough(nx, ny, spreadMax)) continue;
      vis[ny][nx] = true;
      q.add([nx, ny]);
    }
  }
}

void main() {
  const jpegPath = 'assets/images/logos/logo-DARCAR.jpeg';
  const pngPath = 'assets/images/logos/dar_car_logo.png';

  final jpeg = File(jpegPath);
  final pngOut = File(pngPath);
  if (!jpeg.existsSync()) {
    if (pngOut.existsSync()) {
      stdout.writeln(
        'No JPEG at $jpegPath — keeping $pngPath as-is (PNG with transparency). '
        'Run: dart run tool/generate_app_icons.dart',
      );
      return;
    }
    stderr.writeln('Missing $jpegPath and $pngPath');
    exit(1);
  }

  stdout.writeln('Source: $jpegPath');
  final bytes = jpeg.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln('Failed to decode image');
    exit(1);
  }

  _keyDarkPixels(decoded, rgbMax: 78, lumaMax: 88);
  _floodClearFromEdges(decoded, edgeEnter: 92, spreadMax: 96);

  pngOut.writeAsBytesSync(img.encodePng(decoded));
  stdout.writeln('Wrote $pngPath (${decoded.width}x${decoded.height})');
  stdout.writeln('Next: dart run tool/generate_app_icons.dart');
}
