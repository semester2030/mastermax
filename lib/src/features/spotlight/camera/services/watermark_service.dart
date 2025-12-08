import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/camera_config.dart';
import '../../../../core/utils/color_utils.dart';

class WatermarkService {
  Future<String> addWatermark(
    String imagePath,
    String watermarkText,
    Position position,
    double opacity,
    Color color,
    double size,
  ) async {
    final File imageFile = File(imagePath);
    final Uint8List imageBytes = await imageFile.readAsBytes();
    final ui.Image originalImage = await decodeImageFromList(imageBytes);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // Draw original image
    canvas.drawImage(originalImage, Offset.zero, paint);

    // Prepare watermark text
    final textPainter = TextPainter(
      text: TextSpan(
        text: watermarkText,
        style: TextStyle(
          color: ColorUtils.withOpacity(color, opacity),
          fontSize: size,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Calculate watermark position
    final offset = _calculateWatermarkPosition(
      position,
      Size(originalImage.width.toDouble(), originalImage.height.toDouble()),
      textPainter.size,
    );

    // Draw watermark
    textPainter.paint(canvas, offset);

    // Convert to image
    final picture = recorder.endRecording();
    final watermarkedImage = await picture.toImage(
      originalImage.width,
      originalImage.height,
    );
    final byteData = await watermarkedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final watermarkedBytes = byteData!.buffer.asUint8List();

    // Save watermarked image
    final tempDir = await getTemporaryDirectory();
    final watermarkedPath = '${tempDir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.png';
    final watermarkedFile = File(watermarkedPath);
    await watermarkedFile.writeAsBytes(watermarkedBytes);

    return watermarkedPath;
  }

  Offset _calculateWatermarkPosition(
    Position position,
    Size imageSize,
    Size watermarkSize,
  ) {
    switch (position) {
      case Position.topLeft:
        return const Offset(10, 10);
      case Position.topRight:
        return Offset(imageSize.width - watermarkSize.width - 10, 10);
      case Position.bottomLeft:
        return Offset(10, imageSize.height - watermarkSize.height - 10);
      case Position.bottomRight:
        return Offset(
          imageSize.width - watermarkSize.width - 10,
          imageSize.height - watermarkSize.height - 10,
        );
      case Position.center:
        return Offset(
          (imageSize.width - watermarkSize.width) / 2,
          (imageSize.height - watermarkSize.height) / 2,
        );
    }
  }
} 