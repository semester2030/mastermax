// تشغيل من جذر المشروع: dart run tool/generate_app_icons.dart
// يولّد أيقونات مربعة من dar_car_logo.png لأندرويد وiOS والويب.
//
// للأيقونة: نُقصّ الجزء السفلي (النص العربي غير مقروء بحجم الأيقونة) ونكبّر الرسم.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _logoPath = 'assets/images/logos/dar_car_logo.png';

/// نسبة الجزء المقطوع من **أسفل** المصدر (منطقة الاسم/الشعار النصي). 0 = بدون قص.
const _cropBottomFraction = 0.37;

/// خلفية الأيقونة (بيضاء) — الشفافية + شعار عريض كانت تظهر كمربع أسود على أندرويد.
const int _iconBgR = 255;
const int _iconBgG = 255;
const int _iconBgB = 255;

img.Image _sourceForAppIcon(img.Image full) {
  if (_cropBottomFraction <= 0) return full;
  final keepH = (full.height * (1 - _cropBottomFraction)).round();
  if (keepH < 32 || keepH >= full.height) return full;
  return img.copyCrop(
    full,
    x: 0,
    y: 0,
    width: full.width,
    height: keepH,
  );
}

/// يملأ المربع [size]×[size] (مثل `object-fit: cover`) ثم يقصّ من المركز.
/// الشعار العريض مع `contain` كان يصبح شريطاً رفيعاً + شفافية تظهر سوداء على أندرويد.
img.Image _squareIcon(img.Image source, int size) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(
    canvas,
    color: img.ColorRgba8(_iconBgR, _iconBgG, _iconBgB, 255),
  );
  final scale = math.max(
    size / source.width,
    size / source.height,
  );
  final nw = math.max(1, (source.width * scale).round());
  final nh = math.max(1, (source.height * scale).round());
  final resized = img.copyResize(
    source,
    width: nw,
    height: nh,
    interpolation: img.Interpolation.average,
  );
  final cx = ((nw - size) ~/ 2).clamp(0, math.max(0, nw - size)).toInt();
  final cy = ((nh - size) ~/ 2).clamp(0, math.max(0, nh - size)).toInt();
  final cw = math.min(size, nw);
  final ch = math.min(size, nh);
  final slice = img.copyCrop(
    resized,
    x: cx,
    y: cy,
    width: cw,
    height: ch,
  );
  img.compositeImage(canvas, slice, dstX: 0, dstY: 0);
  return canvas;
}

void _writePng(String path, img.Image image) {
  File(path).writeAsBytesSync(img.encodePng(image));
  stdout.writeln(path);
}

void main() {
  final logoFile = File(_logoPath);
  if (!logoFile.existsSync()) {
    stderr.writeln('Missing $_logoPath — run strip_logo_black_background.dart first.');
    exit(1);
  }
  final decoded = img.decodeImage(logoFile.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Failed to decode logo');
    exit(1);
  }
  final iconSource = _sourceForAppIcon(decoded);

  const androidTargets = <String, int>{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  const iosTargets = <String, int>{
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png': 167,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png': 1024,
  };

  const webTargets = <String, int>{
    'web/favicon.png': 48,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
  };

  stdout.writeln('Generating app icons from $_logoPath …');
  for (final e in androidTargets.entries) {
    _writePng(e.key, _squareIcon(iconSource, e.value));
  }
  for (final e in iosTargets.entries) {
    _writePng(e.key, _squareIcon(iconSource, e.value));
  }
  for (final e in webTargets.entries) {
    _writePng(e.key, _squareIcon(iconSource, e.value));
  }
  stdout.writeln('Done.');
}
