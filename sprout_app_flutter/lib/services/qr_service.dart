import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'project_service.dart';
import 'sprout_app_package.dart';

/// QR transport for small Sprout app packages.
///
/// QR is intentionally bounded to smaller packages than file sharing because
/// QR capacity is limited. Larger apps should use `.sproutapp` file sharing.
class QrService {
  static const int maxQrBytes = 64 * 1024;

  static Future<Uint8List> generateQrData(String projectName) async {
    final projects = ProjectService();
    final source = await projects.readFile(projectName, 'main.sprout');
    final state = await projects.readAppState(projectName);
    final bytes = SproutAppPackageService().buildPackageBytes(
      projectName: projectName,
      source: source,
      appState: state,
      includesAppState: state.isNotEmpty,
    );
    if (bytes.length > maxQrBytes) {
      throw const FormatException(
        'This app is too large for QR sharing. Use file sharing instead.',
      );
    }
    return bytes;
  }

  static Widget buildQrWidget(Uint8List data) {
    if (data.isEmpty || data.length > maxQrBytes) {
      throw const FormatException('QR payload is empty or too large');
    }
    return QrImageView(
      data: base64Encode(data),
      version: QrVersions.auto,
      size: 200,
      gapless: false,
    );
  }

  static Future<void> loadFromQrData(Uint8List qrData, String newName) async {
    if (qrData.isEmpty || qrData.length > maxQrBytes) {
      throw const FormatException('Invalid or oversized QR project payload');
    }

    final preview = SproutAppPackageService().inspectBytes(qrData);
    final projects = ProjectService();
    await projects.createProject(newName);
    try {
      await projects.writeFile(newName, 'main.sprout', preview.source);
      if (preview.manifest.includesAppState && preview.appState.isNotEmpty) {
        await projects.writeAppState(newName, preview.appState);
      }
    } catch (_) {
      await projects.deleteProject(newName);
      rethrow;
    }
  }
}
