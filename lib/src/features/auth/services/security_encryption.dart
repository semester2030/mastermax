import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// نظام تشفير البيانات الحساسة
class SecurityEncryption {
  static final SecurityEncryption _instance = SecurityEncryption._internal();
  factory SecurityEncryption() => _instance;

  // مفتاح التشفير الرئيسي - يتم تخزينه بشكل آمن
  static const String _masterKeyId = 'master_encryption_key';
  late final encrypt.Key _key;
  late final encrypt.IV _iv;
  
  final _secureStorage = const FlutterSecureStorage();
  
  SecurityEncryption._internal();

  /// تهيئة نظام التشفير
  Future<void> initialize() async {
    // استرجاع أو إنشاء مفتاح التشفير الرئيسي
    String? storedKey = await _secureStorage.read(key: _masterKeyId);
    
    if (storedKey == null) {
      // إنشاء مفتاح جديد إذا لم يكن موجوداً
      final key = _generateSecureKey();
      await _secureStorage.write(key: _masterKeyId, value: base64.encode(key));
      storedKey = base64.encode(key);
    }

    // تهيئة مفتاح التشفير
    _key = encrypt.Key(base64.decode(storedKey));
    _iv = encrypt.IV.fromSecureRandom(16);
  }

  /// تشفير البيانات الحساسة
  Future<String> encryptSensitiveData(String data) async {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_key));
      final encrypted = encrypter.encrypt(data, iv: _iv);
      
      // تخزين IV مع البيانات المشفرة
      final combined = {
        'iv': base64.encode(_iv.bytes),
        'data': encrypted.base64,
      };
      
      return json.encode(combined);
    } catch (e) {
      throw SecurityException('فشل تشفير البيانات: $e');
    }
  }

  /// فك تشفير البيانات الحساسة
  Future<String> decryptSensitiveData(String encryptedData) async {
    try {
      final Map<String, dynamic> combined = json.decode(encryptedData);
      final iv = encrypt.IV.fromBase64(combined['iv']);
      
      final encrypter = encrypt.Encrypter(encrypt.AES(_key));
      final decrypted = encrypter.decrypt64(combined['data'], iv: iv);
      
      return decrypted;
    } catch (e) {
      throw SecurityException('فشل فك تشفير البيانات: $e');
    }
  }

  /// تشفير كلمة المرور (تجزئة آمنة)
  String hashPassword(String password) {
    // إضافة salt عشوائي
    final salt = _generateSalt();
    final bytes = utf8.encode(password + salt);
    final hash = sha256.convert(bytes);
    
    // تخزين الـ salt مع الهاش
    return base64.encode(utf8.encode('$salt:${hash.toString()}'));
  }

  /// التحقق من تطابق كلمة المرور مع الهاش
  bool verifyPassword(String password, String hashedPassword) {
    try {
      final decoded = utf8.decode(base64.decode(hashedPassword));
      final parts = decoded.split(':');
      if (parts.length != 2) return false;
      
      final salt = parts[0];
      final hash = parts[1];
      
      final bytes = utf8.encode(password + salt);
      final computedHash = sha256.convert(bytes).toString();
      
      return hash == computedHash;
    } catch (e) {
      return false;
    }
  }

  /// تشفير التوكن للتخزين المحلي
  Future<String> encryptToken(String token) async {
    return encryptSensitiveData(token);
  }

  /// فك تشفير التوكن المخزن
  Future<String> decryptToken(String encryptedToken) async {
    return decryptSensitiveData(encryptedToken);
  }

  /// توليد مفتاح آمن
  Uint8List _generateSecureKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256))
    );
  }

  /// توليد salt عشوائي
  String _generateSalt() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256))
    );
    return base64.encode(bytes);
  }

  /// تغيير مفتاح التشفير الرئيسي (مع إعادة تشفير البيانات القديمة)
  Future<void> rotateEncryptionKey() async {
    // حفظ المفتاح القديم
    final oldKey = _key;
    
    // إنشاء مفتاح جديد
    final newKeyBytes = _generateSecureKey();
    final newKey = encrypt.Key(newKeyBytes);
    
    try {
      // تحديث المفتاح في التخزين الآمن
      await _secureStorage.write(
        key: _masterKeyId,
        value: base64.encode(newKeyBytes),
      );
      
      // تحديث المفتاح في الذاكرة
      _key = newKey;
      
      // TODO: إعادة تشفير البيانات المخزنة باستخدام المفتاح الجديد
    } catch (e) {
      // استعادة المفتاح القديم في حالة الفشل
      _key = oldKey;
      throw SecurityException('فشل تحديث مفتاح التشفير: $e');
    }
  }
}

/// استثناء خاص بأخطاء الأمان
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  
  @override
  String toString() => message;
} 