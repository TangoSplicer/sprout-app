import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  // AES-256 key (32 bytes)
  late encrypt.Key _aesKey;
  
  // Initialization vector (16 bytes)
  late encrypt.IV _iv;

  /// Initialize encryption service with a master key
  void initialize(String masterKey) {
    // Derive a 256-bit key from the master key using SHA-256
    final keyBytes = sha256.convert(utf8.encode(masterKey)).bytes;
    _aesKey = encrypt.Key(Uint8List.fromList(keyBytes));
    
    // Generate a random IV
    _iv = encrypt.IV.fromLength(16);
  }

  /// Initialize with secure random key
  void initializeWithRandomKey() {
    final random = SecureRandom('AES/CTR/AUTO-PRNG');
    random.seed(KeyParameter(Platform.instance.platformEntropy()));
    
    final keyBytes = Uint8List(32);
    for (var i = 0; i < keyBytes.length; i++) {
      keyBytes[i] = random.nextUint8();
    }
    
    _aesKey = encrypt.Key(keyBytes);
    
    final ivBytes = Uint8List(16);
    for (var i = 0; i < ivBytes.length; i++) {
      ivBytes[i] = random.nextUint8();
    }
    
    _iv = encrypt.IV(ivBytes);
  }

  /// Encrypt text using AES-256-CBC
  String encryptText(String plainText) {
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_aesKey, mode: encrypt.AESMode.cbc),
    );
    
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  /// Decrypt text using AES-256-CBC
  String decryptText(String encryptedText) {
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_aesKey, mode: encrypt.AESMode.cbc),
    );
    
    final encrypted = encrypt.Encrypted.fromBase64(encryptedText);
    final decrypted = encrypter.decrypt(encrypted, iv: _iv);
    return decrypted;
  }

  /// Encrypt data using AES-256-CBC
  Uint8List encryptData(Uint8List data) {
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_aesKey, mode: encrypt.AESMode.cbc),
    );
    
    final encrypted = encrypter.encryptBytes(data, iv: _iv);
    return encrypted.bytes;
  }

  /// Decrypt data using AES-256-CBC
  Uint8List decryptData(Uint8List encryptedData) {
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_aesKey, mode: encrypt.AESMode.cbc),
    );
    
    final encrypted = encrypt.Encrypted(encryptedData);
    final decrypted = encrypter.decryptBytes(encrypted, iv: _iv);
    return Uint8List.fromList(decrypted);
  }

  /// Encrypt JSON object
  String encryptJson(Map<String, dynamic> jsonData) {
    final jsonString = jsonEncode(jsonData);
    return encryptText(jsonString);
  }

  /// Decrypt JSON object
  Map<String, dynamic> decryptJson(String encryptedJson) {
    final jsonString = decryptText(encryptedJson);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Generate SHA-256 hash
  String generateHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate SHA-256 hash of bytes
  String generateHashBytes(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }

  /// Generate random salt
  String generateSalt({int length = 32}) {
    final random = SecureRandom('AES/CTR/AUTO-PRNG');
    random.seed(KeyParameter(Platform.instance.platformEntropy()));
    
    final saltBytes = Uint8List(length);
    for (var i = 0; i < saltBytes.length; i++) {
      saltBytes[i] = random.nextUint8();
    }
    
    return base64Encode(saltBytes);
  }

  /// Derive key from password using PBKDF2
  String deriveKey(String password, String salt, {int iterations = 10000}) {
    final key = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    
    final saltBytes = base64Decode(salt);
    final passwordBytes = utf8.encode(password);
    
    key.init(Pbkdf2Parameters(
      Uint8List.fromList(saltBytes),
      iterations,
      32, // 256-bit key
    ));
    
    final derivedBytes = Uint8List(32);
    key.deriveKey(
      Uint8List.fromList(passwordBytes),
      0,
      derivedBytes,
      0,
      false,
    );
    
    return base64Encode(derivedBytes);
  }

  /// Verify HMAC signature
  bool verifyHmac(String message, String signature, String key) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(message));
    final computedSignature = digest.toString();
    
    return computedSignature == signature;
  }

  /// Generate HMAC signature
  String generateHmac(String message, String key) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(message));
    return digest.toString();
  }

  /// Get current key (for testing purposes only)
  String getKey() {
    return base64Encode(_aesKey.bytes);
  }

  /// Get current IV (for testing purposes only)
  String getIV() {
    return base64Encode(_iv.bytes);
  }
}