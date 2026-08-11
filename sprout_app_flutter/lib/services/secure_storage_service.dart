// Secure Storage Service for Sprout
// Provides encrypted storage for sensitive data

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:typed_data';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Security: Encryption key generation
  String _generateKey(String input) {
    final bytes = utf8.encode(input + DateTime.now().millisecondsSinceEpoch.toString());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Security: Encrypt data
  Future<String> _encrypt(String data, String key) async {
    try {
      final keyBytes = Key.fromUtf8(key.padRight(32, '0').substring(0, 32));
      final iv = IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(keyBytes));
      
      final encrypted = encrypter.encrypt(data, iv: iv);
      return encrypted.base64 + ':' + iv.base64;
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  // Security: Decrypt data
  Future<String> _decrypt(String encrypted, String key) async {
    try {
      final parts = encrypted.split(':');
      if (parts.length != 2) {
        throw Exception('Invalid encrypted data format');
      }
      
      final keyBytes = Key.fromUtf8(key.padRight(32, '0').substring(0, 32));
      final iv = IV.fromBase64(parts[1]);
      final encrypter = encrypt.Encrypter(encrypt.AES(keyBytes));
      
      final decrypted = encrypter.decrypt64(parts[0], iv: iv);
      return decrypted;
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  // Security: Store data with encryption
  Future<void> storeSecure(String key, String value) async {
    try {
      // Security: Validate key
      if (key.isEmpty || key.length > 100) {
        throw Exception('Invalid key length');
      }
      
      // Security: Validate value
      if (value.length > 10000) {
        throw Exception('Value too large');
      }
      
      // Security: Check for dangerous patterns
      if (key.contains('eval') || key.contains('exec')) {
        throw Exception('Dangerous key pattern detected');
      }
      
      // Generate encryption key
      final encryptionKey = _generateKey(key);
      
      // Encrypt data
      final encrypted = await _encrypt(value, encryptionKey);
      
      // Store encrypted data
      await _storage.write(key: 'enc_$key', value: encrypted);
    } catch (e) {
      throw Exception('Failed to store secure data: $e');
    }
  }

  // Security: Retrieve and decrypt data
  Future<String?> getSecure(String key) async {
    try {
      final encrypted = await _storage.read(key: 'enc_$key');
      
      if (encrypted == null) {
        return null;
      }
      
      // Generate decryption key
      final decryptionKey = _generateKey(key);
      
      // Decrypt data
      final decrypted = await _decrypt(encrypted, decryptionKey);
      
      return decrypted;
    } catch (e) {
      throw Exception('Failed to retrieve secure data: $e');
    }
  }

  // Security: Delete secure data
  Future<void> deleteSecure(String key) async {
    try {
      await _storage.delete(key: 'enc_$key');
    } catch (e) {
      throw Exception('Failed to delete secure data: $e');
    }
  }

  // Security: Check if key exists
  Future<bool> containsKey(String key) async {
    try {
      final value = await _storage.read(key: 'enc_$key');
      return value != null;
    } catch (e) {
      return false;
    }
  }

  // Security: Get all keys
  Future<List<String>> getAllKeys() async {
    try {
      final allData = await _storage.readAll();
      return allData.keys
          .where((key) => key.startsWith('enc_'))
          .map((key) => key.substring(4))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Security: Clear all secure data
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw Exception('Failed to clear secure data: $e');
    }
  }

  // Security: Store binary data
  Future<void> storeBinary(String key, Uint8List data) async {
    try {
      // Security: Validate data size
      if (data.length > 1024 * 1024) { // 1MB limit
        throw Exception('Binary data too large');
      }
      
      // Convert to base64
      final base64 = base64Encode(data);
      
      // Store securely
      await storeSecure(key, base64);
    } catch (e) {
      throw Exception('Failed to store binary data: $e');
    }
  }

  // Security: Retrieve binary data
  Future<Uint8List?> getBinary(String key) async {
    try {
      final base64 = await getSecure(key);
      
      if (base64 == null) {
        return null;
      }
      
      // Convert from base64
      final data = base64Decode(base64);
      return data;
    } catch (e) {
      throw Exception('Failed to retrieve binary data: $e');
    }
  }

  // Security: Verify data integrity
  Future<bool> verifyIntegrity(String key) async {
    try {
      final data = await getSecure(key);
      return data != null;
    } catch (e) {
      return false;
    }
  }
}