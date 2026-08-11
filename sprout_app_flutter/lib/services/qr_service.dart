// flutter/lib/services/qr_service.dart
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
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

  // Parse QR data back to project
  static Future<void> loadFromQrData(Uint8List qrData, String newName) async {
    final tarData = GZipDecoder().decodeBytes(qrData);
    final archive = TarDecoder().decodeBytes(tarData);
    
    // We need to create the project first
    await ProjectService().createProject(newName);
    
    // In a real app, we'd need a way to get the project path
    // For now, this is a simplified version
  }
}
