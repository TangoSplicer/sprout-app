// flutter/lib/services/secure_export.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'e2ee.dart';
import 'project_service.dart';

class SecureExport {
  static Future<File> exportEncrypted(String projectName, ECPublicKey recipientKey) async {
    final content = await ProjectService().readFile(projectName, 'main.sprout');
    final encrypted = await E2EE().encrypt(content, recipientKey);

    final file = File(p.join(Directory.systemTemp.path, '$projectName.sprout'));
    await file.writeAsString(encrypted);
    return file;
  }

  static Future<void> importEncrypted(File file, String newName, ECPrivateKey myKey, ECPublicKey senderKey) async {
    final encrypted = await file.readAsString();
    final decrypted = await E2EE().decrypt(encrypted, myKey, senderKey);
    await ProjectService().createProject(newName);
    await ProjectService().writeFile(newName, 'main.sprout', decrypted);
  }
}