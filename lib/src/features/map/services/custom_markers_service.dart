import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/pin_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class CustomMarkersService {
  /// ماركر دائري من أول صورة URL (للعقارات/السيارات على الخريطة).
  static Future<BitmapDescriptor?> fromNetworkImageUrl(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final png = await _circularImagePngBytes(Uint8List.fromList(response.bodyBytes));
      return BitmapDescriptor.fromBytes(png);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> _circularImagePngBytes(Uint8List imageBytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image originalImage = frameInfo.image;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const width = 120.0;
    const height = 120.0;

    final shadowPaint = Paint()
      ..color = ColorUtils.withOpacity(AppColors.black, 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      const Offset(width / 2, height / 2),
      width / 2,
      shadowPaint,
    );

    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(
      const Offset(width / 2, height / 2),
      (width / 2) - 2,
      borderPaint,
    );

    final clipPath = Path()
      ..addOval(Rect.fromCircle(
        center: const Offset(width / 2, height / 2),
        radius: (width / 2) - 4,
      ));

    canvas.save();
    canvas.clipPath(clipPath);

    final aspectRatio = originalImage.width / originalImage.height;
    if (aspectRatio > 1) {
      final targetWidth = height * aspectRatio;
      final offset = (targetWidth - width) / 2;
      canvas.drawImageRect(
        originalImage,
        Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
        Rect.fromLTWH(-offset, 0, targetWidth, height),
        Paint()..filterQuality = FilterQuality.high,
      );
    } else {
      final targetHeight = width / aspectRatio;
      final offset = (targetHeight - height) / 2;
      canvas.drawImageRect(
        originalImage,
        Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
        Rect.fromLTWH(0, -offset, width, targetHeight),
        Paint()..filterQuality = FilterQuality.high,
      );
    }

    canvas.restore();

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// إنشاء BitmapDescriptor من PinConfig
  static Future<BitmapDescriptor> createMarkerIcon(PinConfig config) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = config.size;

    // رسم الظل
    if (config.showGlow) {
      final shadowPaint = Paint()
        ..color = ColorUtils.withOpacity(AppColors.black, 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2,
        shadowPaint,
      );
    }

    // رسم الدائرة الرئيسية
    final circlePaint = Paint()
      ..color = config.color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      circlePaint,
    );

    // رسم الحدود
    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      borderPaint,
    );

    // رسم الأيقونة
    if (config.icon != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(config.icon!.codePoint),
          style: TextStyle(
            fontSize: size * 0.4,
            fontFamily: config.icon!.fontFamily,
            color: config.iconColor ?? AppColors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size - textPainter.width) / 2,
          (size - textPainter.height) / 2,
        ),
      );
    }

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(pngBytes);
  }

  /// إنشاء marker مخصص حسب النوع
  static Future<BitmapDescriptor> createMarkerByType(PinGlyph type) async {
    switch (type) {
      case PinGlyph.home:
        return createMarkerIcon(
          PinConfig(
            color: AppColors.primary,
            icon: Icons.home,
            showGlow: true,
          ),
        );
      case PinGlyph.car:
        return createMarkerIcon(
          PinConfig(
            color: AppColors.success,
            icon: Icons.directions_car,
            showGlow: true,
          ),
        );
      case PinGlyph.location:
        return createMarkerIcon(
          PinConfig(
            color: AppColors.error,
            icon: Icons.location_on,
            showGlow: true,
          ),
        );
      case PinGlyph.star:
        return createMarkerIcon(
          PinConfig(
            color: AppColors.primaryLight,
            icon: Icons.star,
            showGlow: true,
          ),
        );
      case PinGlyph.custom:
        return createMarkerIcon(
          PinConfig(
            color: AppColors.primary,
            showGlow: true,
          ),
        );
    }
  }
}

