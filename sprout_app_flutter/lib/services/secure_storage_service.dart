import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key-value storage protected by Android EncryptedSharedPreferences and the
/// iOS Keychain. Values are not additionally encrypted in Dart because doing
/// so requires a persistent key lifecycle; the platform store supplies that.
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  static final RegExp _keyPattern = RegExp(r'^[A-Za-z0-9_.-]{1,100}$');

  factory SecureStorageService() => _instance;

  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> storeSecure(String key, String value) async {
    _validateKey(key);
    if (value.length > 1024 * 1024) {
      throw ArgumentError.value(value.length, 'value', 'Value exceeds 1 MiB');
    }
    await _storage.write(key: _storageKey(key), value: value);
  }

  Future<String?> getSecure(String key) async {
    _validateKey(key);
    return _storage.read(key: _storageKey(key));
  }

  Future<void> deleteSecure(String key) async {
    _validateKey(key);
    await _storage.delete(key: _storageKey(key));
  }

  Future<bool> containsKey(String key) async {
    _validateKey(key);
    return _storage.containsKey(key: _storageKey(key));
  }

  Future<List<String>> getAllKeys() async {
    final values = await _storage.readAll();
    return values.keys
        .where((key) => key.startsWith('sprout.'))
        .map((key) => key.substring('sprout.'.length))
        .toList(growable: false);
  }

  Future<void> clearAll() => _storage.deleteAll();

  Future<void> storeBinary(String key, Uint8List data) {
    if (data.length > 1024 * 1024) {
      throw ArgumentError.value(
          data.length, 'data', 'Binary data exceeds 1 MiB');
    }
    return storeSecure(key, base64Encode(data));
  }

  Future<Uint8List?> getBinary(String key) async {
    final encoded = await getSecure(key);
    return encoded == null ? null : Uint8List.fromList(base64Decode(encoded));
  }

  Future<bool> verifyIntegrity(String key) async {
    try {
      return await containsKey(key);
    } on ArgumentError {
      return false;
    }
  }

  String _storageKey(String key) => 'sprout.$key';

  void _validateKey(String key) {
    if (!_keyPattern.hasMatch(key)) {
      throw ArgumentError.value(key, 'key',
          'Use 1-100 alphanumeric, dot, underscore, or hyphen characters');
    }
  }
}
