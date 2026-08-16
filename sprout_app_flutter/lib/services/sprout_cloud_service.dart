import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'sprout_app_package.dart';

/// SproutCloudService provides the foundation for zero-knowledge encrypted backups.
/// In this release, it implements local encryption of .sproutapp packages
/// as a precursor to secure cloud synchronization.
class SproutCloudService {
  static final SproutCloudService _instance = SproutCloudService._internal();
  factory SproutCloudService() => _instance;
  SproutCloudService._internal();

  /// Encrypts a project into a .sproutcloud bundle using a user-provided passphrase.
  Future<File> createEncryptedBackup(String projectName, String passphrase) async {
    // 1. Create a standard portable package first
    final package = await SproutAppPackageService().exportProject(
      projectName,
      includeAppState: true,
    );

    // 2. Derive a key from the passphrase
    final key = _deriveKey(passphrase);
    
    // 3. Read package bytes
    final bytes = await package.file.readAsBytes();
    
    // 4. "Encrypt" bytes (Mock encryption for test build using XOR with key hash)
    // In production, this would use AES-GCM via a native library or package:cryptography
    final encryptedBytes = _xorBytes(bytes, key);
    
    // 5. Save to .sproutcloud file
    final backupDir = p.dirname(package.file.path);
    final backupFile = File(p.join(backupDir, '$projectName.sproutcloud'));
    await backupFile.writeAsBytes(encryptedBytes);
    
    return backupFile;
  }

  /// Decrypts a .sproutcloud bundle and returns the path to the temporary .sproutapp package.
  Future<File> decryptBackup(File backupFile, String passphrase) async {
    final key = _deriveKey(passphrase);
    final bytes = await backupFile.readAsBytes();
    
    // Decrypt (Mock XOR)
    final decryptedBytes = _xorBytes(bytes, key);
    
    final tempDir = p.dirname(backupFile.path);
    final tempPackage = File(p.join(tempDir, 'decrypted_import.sproutapp'));
    await tempPackage.writeAsBytes(decryptedBytes);
    
    return tempPackage;
  }

  Uint8List _deriveKey(String passphrase) {
    return Uint8List.fromList(sha256.convert(utf8.encode(passphrase)).bytes);
  }

  Uint8List _xorBytes(Uint8List bytes, Uint8List key) {
    final result = Uint8List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      result[i] = bytes[i] ^ key[i % key.length];
    }
    return result;
  }
}
