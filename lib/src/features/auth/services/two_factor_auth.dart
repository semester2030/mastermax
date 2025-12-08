// مكتبات مطلوبة للمصادقة الثنائية
// dart:convert مطلوبة للتعامل مع:
// - تشفير وفك تشفير البيانات في TOTP
// - معالجة البايتات في عمليات التحويل
// - دعم عمليات base32 والتشفير
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:base32/base32.dart';
import 'security_encryption.dart';

/// نظام المصادقة الثنائية
class TwoFactorAuth {
  static final TwoFactorAuth _instance = TwoFactorAuth._internal();
  factory TwoFactorAuth() => _instance;

  final SecurityEncryption _encryption = SecurityEncryption();
  static const int _totpDigits = 6;
  static const int _totpInterval = 30;
  static const String _issuer = 'MasterMax';

  TwoFactorAuth._internal();

  /// إنشاء مفتاح سري جديد للمصادقة الثنائية
  Future<String> generateSecretKey() async {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(20, (_) => random.nextInt(256))
    );
    return base32.encode(bytes).replaceAll('=', '');
  }

  /// إنشاء رابط لتطبيق Google Authenticator
  String generateAuthenticatorUri(String secretKey, String userIdentifier) {
    final encodedIssuer = Uri.encodeComponent(_issuer);
    final encodedUser = Uri.encodeComponent(userIdentifier);
    return 'otpauth://totp/$encodedIssuer:$encodedUser?'
        'secret=$secretKey&issuer=$encodedIssuer&'
        'algorithm=SHA1&digits=$_totpDigits&period=$_totpInterval';
  }

  /// توليد رمز TOTP
  String generateTOTP(String secretKey) {
    final timeCounter = (DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ _totpInterval;
    return _generateCode(secretKey, timeCounter);
  }

  /// التحقق من صحة رمز TOTP
  bool verifyTOTP(String secretKey, String userCode) {
    if (userCode.length != _totpDigits) return false;

    final timeCounter = (DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ _totpInterval;
    
    // التحقق من الرمز الحالي والرمز السابق للسماح بتأخر قليل
    for (var i = -1; i <= 1; i++) {
      final code = _generateCode(secretKey, timeCounter + i);
      if (code == userCode) return true;
    }
    
    return false;
  }

  /// توليد رمز التحقق
  String _generateCode(String secretKey, int counter) {
    // فك تشفير المفتاح السري
    final key = base32.decode(secretKey.padRight(32, '='));
    
    // تحويل العداد إلى بايتات
    final counterBytes = Uint8List(8);
    ByteData.view(counterBytes.buffer).setInt64(0, counter);
    
    // إنشاء HMAC
    final hmac = Hmac(sha1, key);
    final hash = hmac.convert(counterBytes);
    
    // استخراج الرمز
    final offset = hash.bytes[hash.bytes.length - 1] & 0xf;
    final binary = ((hash.bytes[offset] & 0x7f) << 24) |
                  ((hash.bytes[offset + 1] & 0xff) << 16) |
                  ((hash.bytes[offset + 2] & 0xff) << 8) |
                  (hash.bytes[offset + 3] & 0xff);
    
    final otp = binary % pow(10, _totpDigits);
    return otp.toString().padLeft(_totpDigits, '0');
  }

  /// تشفير المفتاح السري للتخزين
  Future<String> encryptSecretKey(String secretKey) async {
    return _encryption.encryptSensitiveData(secretKey);
  }

  /// فك تشفير المفتاح السري المخزن
  Future<String> decryptSecretKey(String encryptedKey) async {
    return _encryption.decryptSensitiveData(encryptedKey);
  }

  /// التحقق من صحة رمز الاسترداد
  Future<bool> verifyBackupCode(String hashedCode, String userCode) async {
    return _encryption.verifyPassword(userCode, hashedCode);
  }

  /// توليد رموز استرداد
  List<String> generateBackupCodes({int count = 8}) {
    final random = Random.secure();
    final codes = <String>[];
    
    for (var i = 0; i < count; i++) {
      final code = List<int>.generate(8, (_) => random.nextInt(10))
          .join()
          .padLeft(8, '0');
      codes.add(code);
    }
    
    return codes;
  }

  /// تجزئة رموز الاسترداد للتخزين
  List<String> hashBackupCodes(List<String> codes) {
    return codes.map(_encryption.hashPassword).toList();
  }

  /// التحقق من صلاحية المفتاح السري
  bool isValidSecretKey(String secretKey) {
    try {
      final decoded = base32.decode(secretKey.padRight(32, '='));
      return decoded.length == 20;
    } catch (e) {
      return false;
    }
  }
} 