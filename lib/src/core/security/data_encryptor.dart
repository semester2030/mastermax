import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class DataEncryptor {
  static final DataEncryptor _instance = DataEncryptor._internal();
  factory DataEncryptor() => _instance;
  DataEncryptor._internal();

  late final Key _key;
  late final IV _iv;
  late final Encrypter _encrypter;
  bool _isInitialized = false;

  void initialize(String secretKey) {
    if (_isInitialized) return;

    final keyBytes = sha256.convert(utf8.encode(secretKey)).bytes;
    _key = Key(Uint8List.fromList(keyBytes));
    _iv = IV.fromLength(16);
    _encrypter = Encrypter(AES(_key));
    _isInitialized = true;
  }

  String encrypt(String data) {
    _checkInitialization();
    return _encrypter.encrypt(data, iv: _iv).base64;
  }

  String decrypt(String encryptedData) {
    _checkInitialization();
    return _encrypter.decrypt64(encryptedData, iv: _iv);
  }

  String encryptJson(Map<String, dynamic> data) {
    _checkInitialization();
    final jsonString = jsonEncode(data);
    return encrypt(jsonString);
  }

  Map<String, dynamic> decryptJson(String encryptedData) {
    _checkInitialization();
    final jsonString = decrypt(encryptedData);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha512.convert(bytes).toString();
  }

  bool verifyPassword(String password, String hashedPassword) {
    final hashedInput = hashPassword(password);
    return hashedInput == hashedPassword;
  }

  String generateToken(Map<String, dynamic> payload, {Duration? expiry}) {
    _checkInitialization();
    
    final now = DateTime.now();
    final expiryTime = expiry != null ? now.add(expiry) : null;
    
    final tokenData = {
      ...payload,
      'iat': now.millisecondsSinceEpoch,
      if (expiryTime != null) 'exp': expiryTime.millisecondsSinceEpoch,
    };

    return encryptJson(tokenData);
  }

  Map<String, dynamic>? verifyToken(String token) {
    try {
      final payload = decryptJson(token);
      final expiry = payload['exp'] as int?;
      
      if (expiry != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry);
        if (DateTime.now().isAfter(expiryDate)) {
          return null;
        }
      }
      
      return payload;
    } catch (e) {
      return null;
    }
  }

  void _checkInitialization() {
    if (!_isInitialized) {
      throw StateError('DataEncryptor not initialized. Call initialize() first.');
    }
  }

  Uint8List encryptBytes(Uint8List data) {
    _checkInitialization();
    final encrypted = _encrypter.encryptBytes(data, iv: _iv);
    return Uint8List.fromList(encrypted.bytes);
  }

  Uint8List decryptBytes(Uint8List encryptedData) {
    _checkInitialization();
    final encrypted = Encrypted(encryptedData);
    return Uint8List.fromList(_encrypter.decryptBytes(encrypted, iv: _iv));
  }

  String generateSecureRandomString(int length) {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }
} 