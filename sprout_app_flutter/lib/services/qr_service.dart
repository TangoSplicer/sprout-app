// flutter/lib/services/qr_service.dart
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:archive/archive.dart';
import 'project_service.dart';

class QrService {
  // Generate QR data from project
  static Future<Uint8List> generateQrData(String projectName) async {
    final archive = Archive();
    // For now, just include main.sprout and project.json
    final files = ['main.sprout', 'project.json'];
    for (final file in files) {
      try {
        final content = await ProjectService().readFile(projectName, file);
        final bytes = utf8.encode(content);
        archive.addFile(ArchiveFile(file, bytes.length, bytes));
      } catch (e) {
        // Skip files that don't exist
      }
    }
    final tarData = TarEncoder().encode(archive);
    final zipData = GZipEncoder().encode(tarData);
    return Uint8List.fromList(zipData!);
  }

  // Generate QR widget
  static Widget buildQrWidget(Uint8List data) {
    return QrImageView(
      data: base64Encode(data),
      version: QrVersions.auto,
      size: 200,
      gapless: false,
    );
  }

  // Parse QR data back to a project. Only the expected source file is restored.
  static Future<void> loadFromQrData(Uint8List qrData, String newName) async {
    if (qrData.isEmpty || qrData.length > 1024 * 1024) {
      throw const FormatException('Invalid or oversized QR project payload');
    }

    final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(qrData));
    final sourceFile = archive.files.where(
      (file) => file.isFile && file.name == 'main.sprout',
    );
    if (sourceFile.isEmpty) {
      throw const FormatException(
          'QR project payload does not contain main.sprout');
    }

    final content = utf8.decode(sourceFile.first.content as List<int>,
        allowMalformed: false);
    final projects = ProjectService();
    await projects.createProject(newName);
    await projects.writeFile(newName, 'main.sprout', content);
  }
}
