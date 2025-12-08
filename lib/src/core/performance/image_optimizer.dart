import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageOptimizer {
  static final ImageOptimizer _instance = ImageOptimizer._internal();
  factory ImageOptimizer() => _instance;
  ImageOptimizer._internal();

  Future<File?> compressImage(File file, {
    int quality = 85,
    int? targetWidth,
    int? targetHeight,
    int? minWidth = 0,
    int? minHeight = 0,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        '${path.basenameWithoutExtension(file.path)}_compressed${path.extension(file.path)}',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: minWidth ?? 0,
        minHeight: minHeight ?? 0,
        format: _getCompressFormat(file.path),
      );

      if (result == null) {
        if (kDebugMode) {
          debugPrint('Failed to compress image: ${file.path}');
        }
        return null;
      }

      return File(result.path);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error compressing image: $e');
      }
      return null;
    }
  }

  Future<List<File>?> compressImages(List<File> files, {
    int quality = 85,
    int? targetWidth,
    int? targetHeight,
    int? minWidth = 0,
    int? minHeight = 0,
  }) async {
    try {
      final compressedFiles = <File>[];

      for (final file in files) {
        final compressedFile = await compressImage(
          file,
          quality: quality,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
          minWidth: minWidth,
          minHeight: minHeight,
        );

        if (compressedFile != null) {
          compressedFiles.add(compressedFile);
        }
      }

      return compressedFiles;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error compressing images: $e');
      }
      return null;
    }
  }

  Future<File?> resizeImage(File file, {
    required int width,
    required int height,
    int quality = 85,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        '${path.basenameWithoutExtension(file.path)}_resized${path.extension(file.path)}',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: width,
        minHeight: height,
        format: _getCompressFormat(file.path),
      );

      if (result == null) {
        if (kDebugMode) {
          debugPrint('Failed to resize image: ${file.path}');
        }
        return null;
      }

      return File(result.path);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error resizing image: $e');
      }
      return null;
    }
  }

  CompressFormat _getCompressFormat(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return CompressFormat.jpeg;
      case '.png':
        return CompressFormat.png;
      case '.heic':
        return CompressFormat.heic;
      case '.webp':
        return CompressFormat.webp;
      default:
        return CompressFormat.jpeg;
    }
  }

  Future<bool> isValidImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      await codec.getNextFrame();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, int>?> getImageDimensions(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return {
        'width': frame.image.width,
        'height': frame.image.height,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting image dimensions: $e');
      }
      return null;
    }
  }

  Future<int?> getFileSize(File file) async {
    try {
      final bytes = await file.length();
      return bytes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting file size: $e');
      }
      return null;
    }
  }

  String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }
} 