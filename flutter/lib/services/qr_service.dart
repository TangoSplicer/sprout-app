// flutter/lib/services/qr_service.dart
import 'dart:typed_data';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show Uint8List;

class QrService {
  // Generate QR data from project
  static Future<Uint8List> generateQrData(String projectName) async {
    final archive = Archive();
    final files = await ProjectService().listFiles(projectName);
    for (final file in files) {
      final content = await ProjectService().readFile(projectName, file);
      archive.addFile(ArchiveFile(file, content.length, content.codeUnits));
    }
    final tarData = Archive.tarBytes(archive);
    final zipData = GZipEncoder().encode(tarData);
    return Uint8List.fromList(zipData!);
  }

  // Generate QR widget
  static Widget buildQrWidget(Uint8List data) {
    return QrImageView(
       base64Encode(data),
      version: QrVersions.auto,
      size: 200,
      gapless: false,
    );
  }

  // Parse QR data back to project
  static Future<void> loadFromQrData(Uint8List qrData, String newName) async {
    final tarData = GZipDecoder().decodeBytes(qrData);
    final archive = TarDecoder().decodeBytes(tarData);
    final root = await ProjectService()._getProjectsDir();
    final projectDir = Directory('${root.path}/$newName');
    await projectDir.create();

    for (final file in archive) {
      final filePath = p.join(projectDir.path, file.name);
      if (file.isFile) {
        final content = String.fromCharCodes(file.content as List<int>);
        await File(filePath).writeAsString(content);
      }
    }
  }
}