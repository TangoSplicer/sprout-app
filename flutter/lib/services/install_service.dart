// flutter/lib/services/install_service.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class InstallService {
  static Future<bool> canInstall() async {
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      return status.isGranted;
    }
    return true; // iOS: manual install
  }

  static Future<void> installApp(String projectName) async {
    final projectDir = await ProjectService().getProjectPath(projectName);
    final outputDir = Directory.systemTemp;
    final apkPath = p.join(outputDir.path, '$projectName.apk');

    // In real version: call Rust or shell script
    print("Generating APK for $projectName...");

    // Simulate APK
    final file = File(apkPath);
    await file.create();
    await file.writeAsString("APK for $projectName");

    if (Platform.isAndroid) {
      if (await canInstall()) {
        final result = await OpenFile.open(apkPath);
        if (result.type != ResultType.done) {
          throw Exception("Failed to open APK: ${result.message}");
        }
      } else {
        await Permission.requestInstallPackages.request();
      }
    } else if (Platform.isIOS) {
      // Show guide
      _showIOSInstallGuide();
    }
  }

  static void _showIOSInstallGuide() {
    // Show modal with steps: export to Xcode, build, install
  }
}