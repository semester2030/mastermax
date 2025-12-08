import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart' as intl;

class Helpers {
  static String generateUniqueId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomString = List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
    return '$timestamp$randomString';
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  static String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  static bool isImageFile(String filePath) {
    final ext = getFileExtension(filePath);
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
  }

  static bool isVideoFile(String filePath) {
    final ext = getFileExtension(filePath);
    return ['.mp4', '.mov', '.avi', '.mkv', '.wmv'].contains(ext);
  }

  static bool isDocumentFile(String filePath) {
    final ext = getFileExtension(filePath);
    return ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.txt'].contains(ext);
  }

  static String formatCurrency(double amount, {String symbol = 'ر.س'}) {
    final formatter = intl.NumberFormat('#,##0.00', 'ar');
    return '${formatter.format(amount)} $symbol';
  }

  static String formatNumber(num number) {
    return intl.NumberFormat('#,##0.##', 'ar').format(number);
  }

  static String formatPercentage(double percentage) {
    return '${intl.NumberFormat('#,##0.#', 'ar').format(percentage)}%';
  }

  static Color getContrastColor(Color backgroundColor) {
    return ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static Future<bool> checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} سنة';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} شهر';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  static String getRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  static String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  static String getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  static Color getRandomColor() {
    final random = Random();
    return Color.fromRGBO(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      1,
    );
  }

  static String formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.length != 10) return phoneNumber;
    return '${phoneNumber.substring(0, 3)} ${phoneNumber.substring(3, 6)} ${phoneNumber.substring(6)}';
  }

  static bool isValidSaudiPhoneNumber(String phoneNumber) {
    return RegExp(r'^(05)[0-9]{8}$').hasMatch(phoneNumber);
  }

  static bool isValidSaudiID(String id) {
    if (id.length != 10) return false;
    if (!RegExp(r'^[0-9]{10}$').hasMatch(id)) return false;
    
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      int digit = int.parse(id[i]);
      if (i % 2 == 0) {
        digit *= 2;
        if (digit > 9) digit = (digit % 10) + 1;
      }
      sum += digit;
    }
    
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(id[9]);
  }

  static String maskCreditCard(String number) {
    if (number.length < 4) return number;
    return '****${number.substring(number.length - 4)}';
  }

  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    
    final username = parts[0];
    final domain = parts[1];
    
    if (username.length <= 2) return email;
    return '${username[0]}***${username[username.length - 1]}@$domain';
  }
} 