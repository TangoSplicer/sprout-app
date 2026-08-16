import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  static const _masterKeyStorageKey = 'sprout.encryption.master_key.v1';

  factory EncryptionService() => _instance;

  EncryptionService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> initialize(String masterKey) async {
    final keyBytes = sha256.convert(utf8.encode(masterKey)).bytes;
    await _storage.write(
      key: _masterKeyStorageKey,
      value: base64Encode(keyBytes),
    );
  }

  Future<void> initializeWithRandomKey() async {
    await _storage.write(
      key: _masterKeyStorageKey,
      value: base64Encode(_secureBytes(32)),
    );
  }

  /// Encrypt text using AES-256-GCM. Each value has a fresh 96-bit nonce and
  /// carries its authentication tag in the encrypted payload.
  Future<String> encryptText(String plainText) async {
    final key = await _getKey();
    final nonce = _secureBytes(12);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    final ciphertext = encrypter.encrypt(plainText, iv: encrypt.IV(nonce));
    return jsonEncode({
      'version': 1,
      'nonce': base64Encode(nonce),
      'ciphertext': ciphertext.base64,
    });
  }

  Future<String> decryptText(String encryptedText) async {
    final envelope = _decodeEnvelope(encryptedText);
    final key = await _getKey();
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    try {
      return encrypter.decrypt64(
        envelope.ciphertext,
        iv: encrypt.IV(envelope.nonce),
      );
    } on ArgumentError {
      throw const FormatException('Encrypted payload failed authentication');
    }
  }

  Future<Uint8List> encryptData(Uint8List data) async {
    final envelope = await encryptText(base64Encode(data));
    return Uint8List.fromList(utf8.encode(envelope));
  }

  Future<Uint8List> decryptData(Uint8List encryptedData) async {
    final plaintext = await decryptText(utf8.decode(encryptedData));
    return Uint8List.fromList(base64Decode(plaintext));
  }

  Future<String> encryptJson(Map<String, dynamic> jsonData) =>
      encryptText(jsonEncode(jsonData));

  Future<Map<String, dynamic>> decryptJson(String encryptedJson) async =>
      jsonDecode(await decryptText(encryptedJson)) as Map<String, dynamic>;

  String generateHash(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  String generateHashBytes(Uint8List data) => sha256.convert(data).toString();

  String generateSalt({int length = 32}) {
    if (length < 16 || length > 1024) {
      throw ArgumentError.value(
          length, 'length', 'Must be between 16 and 1024');
    }
    return base64Encode(_secureBytes(length));
  }

  String deriveKey(String password, String salt, {int iterations = 210000}) {
    if (iterations < 100000) {
      throw ArgumentError.value(
          iterations, 'iterations', 'Use at least 100,000 iterations');
    }
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(base64Decode(salt), iterations, 32));
    final output = Uint8List(32);
    derivator.deriveKey(
        Uint8List.fromList(utf8.encode(password)), 0, output, 0);
    return base64Encode(output);
  }

  bool verifyHmac(String message, String signature, String key) {
    final expected = generateHmac(message, key);
    return _constantTimeEquals(utf8.encode(expected), utf8.encode(signature));
  }

  String generateHmac(String message, String key) =>
      Hmac(sha256, utf8.encode(key)).convert(utf8.encode(message)).toString();

  Future<String> getKey() async => base64Encode((await _getKey()).bytes);

  Future<String> getIV() async => throw UnsupportedError(
      'AES-GCM uses a distinct nonce for each encryption operation');

  Future<encrypt.Key> _getKey() async {
    var encoded = await _storage.read(key: _masterKeyStorageKey);
    if (encoded == null) {
      encoded = base64Encode(_secureBytes(32));
      await _storage.write(key: _masterKeyStorageKey, value: encoded);
    }
    final bytes = base64Decode(encoded);
    if (bytes.length != 32) {
      throw const FormatException('Invalid persisted encryption key');
    }
    return encrypt.Key(Uint8List.fromList(bytes));
  }

  _EncryptionEnvelope _decodeEnvelope(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Unsupported encrypted payload');
    }
    final nonce = base64Decode(decoded['nonce'] as String);
    if (nonce.length != 12) {
      throw const FormatException('Invalid AES-GCM nonce');
    }
    return _EncryptionEnvelope(
      nonce: Uint8List.fromList(nonce),
      ciphertext: decoded['ciphertext'] as String,
    );
  }

  Uint8List _secureBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}

class _EncryptionEnvelope {
  final Uint8List nonce;
  final String ciphertext;

  const _EncryptionEnvelope({required this.nonce, required this.ciphertext});
}
