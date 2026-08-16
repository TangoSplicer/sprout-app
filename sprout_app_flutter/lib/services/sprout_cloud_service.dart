import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart';

import 'sprout_app_package.dart';

/// Creates and restores local-first, passphrase-protected Sprout Cloud bundles.
///
/// The bundle uses PBKDF2-HMAC-SHA256 with a per-backup salt and AES-256-GCM
/// with a fresh nonce. The authenticated ciphertext detects wrong passphrases
/// and tampering before an imported package is handed to the package service.
class SproutCloudService {
  static final SproutCloudService _instance = SproutCloudService._internal();
  static const int _formatVersion = 2;
  static const int _pbkdf2Iterations = 210000;
  static const int _saltLength = 32;
  static const int _nonceLength = 12;

  factory SproutCloudService() => _instance;
  SproutCloudService._internal();

  /// Encrypts a project into a `.sproutcloud` bundle using a user passphrase.
  Future<File> createEncryptedBackup(
    String projectName,
    String passphrase,
  ) async {
    _validatePassphrase(passphrase);

    final package = await SproutAppPackageService().exportProject(
      projectName,
      includeAppState: true,
    );
    final plaintext = await package.file.readAsBytes();
    final salt = _secureBytes(_saltLength);
    final nonce = _secureBytes(_nonceLength);
    final key = _deriveKey(passphrase, salt);
    final encrypted = _encrypt(plaintext, key, nonce);
    final envelope = <String, Object>{
      'format': 'sproutcloud',
      'version': _formatVersion,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _pbkdf2Iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(encrypted),
    };

    final backupFile = File(
      p.join(p.dirname(package.file.path), '$projectName.sproutcloud'),
    );
    await backupFile.writeAsString(jsonEncode(envelope), flush: true);
    return backupFile;
  }

  /// Decrypts a `.sproutcloud` bundle into a temporary `.sproutapp` archive.
  Future<File> decryptBackup(File backupFile, String passphrase) async {
    _validatePassphrase(passphrase);
    final raw = await backupFile.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'sproutcloud' ||
        decoded['version'] != _formatVersion ||
        decoded['kdf'] != 'PBKDF2-HMAC-SHA256') {
      throw const FormatException('Unsupported Sprout Cloud backup format');
    }

    if (decoded['iterations'] != _pbkdf2Iterations) {
      throw const FormatException('Unsupported Sprout Cloud KDF parameters');
    }
    final salt = _decodeBytes(decoded['salt'], _saltLength, 'salt');
    final nonce = _decodeBytes(decoded['nonce'], _nonceLength, 'nonce');
    final ciphertext = _decodeBytes(decoded['ciphertext'], null, 'ciphertext');

    final key = _deriveKey(passphrase, salt);
    final plaintext = _decrypt(ciphertext, key, nonce);
    final tempPackage = File(
      p.join(
        p.dirname(backupFile.path),
        'decrypted_import_${DateTime.now().microsecondsSinceEpoch}.sproutapp',
      ),
    );
    await tempPackage.writeAsBytes(plaintext, flush: true);
    return tempPackage;
  }

  Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, 32));
    final output = Uint8List(32);
    derivator.deriveKey(
      Uint8List.fromList(utf8.encode(passphrase)),
      0,
      output,
      0,
    );
    return output;
  }

  Uint8List _encrypt(Uint8List plaintext, Uint8List key, Uint8List nonce) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
      );
    return cipher.process(plaintext);
  }

  Uint8List _decrypt(Uint8List ciphertext, Uint8List key, Uint8List nonce) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
      );
    try {
      return cipher.process(ciphertext);
    } on InvalidCipherTextException {
      throw const FormatException('Encrypted backup failed authentication');
    } catch (_) {
      throw const FormatException('Encrypted backup failed authentication');
    }
  }

  Uint8List _decodeBytes(Object? value, int? expectedLength, String name) {
    if (value is! String || value.isEmpty) {
      throw FormatException('Encrypted backup has no $name');
    }
    try {
      final bytes = base64Decode(value);
      if (expectedLength != null && bytes.length != expectedLength) {
        throw FormatException('Invalid encrypted backup $name');
      }
      return Uint8List.fromList(bytes);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw FormatException('Invalid encrypted backup $name');
    }
  }

  Uint8List _secureBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  void _validatePassphrase(String passphrase) {
    if (passphrase.trim().length < 12) {
      throw const FormatException(
        'Use a passphrase with at least 12 characters for encrypted backups',
      );
    }
  }
}
