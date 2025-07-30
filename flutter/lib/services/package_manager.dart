// flutter/lib/services/package_manager.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';

class PackageManager {
  static final PackageManager _instance = PackageManager._internal();
  factory PackageManager() => _instance;
  PackageManager._internal();

  final String registryBase = 'https://pkg.sprout.garden'; // Can be GitHub raw or IPFS

  Future<void> installPackage(String spec) async {
    final (name, source) = _parseSpec(spec);
    final url = _resolveUrl(source);
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to download package: $spec');
    }

    final zipData = response.bodyBytes;
    final archive = ZipDecoder().decodeBytes(zipData);
    final packageDir = await _getPackageDir(name);

    for (final file in archive) {
      final filePath = p.join(packageDir.path, file.name);
      final fileDir = Directory(p.dirname(filePath));
      if (!await fileDir.exists()) await fileDir.create(recursive: true);

      if (file.isFile) {
        final content = String.fromCharCodes(file.content as List<int>);
        await File(filePath).writeAsString(content);
      }
    }
  }

  (String, String) _parseSpec(String spec) {
    if (spec.startsWith('@sprout/')) {
      final name = spec.split('/').last;
      return (name, 'official/$name');
    } else if (spec.contains('/')) {
      return (spec.split('/').last, 'community/$spec');
    } else {
      return (spec, 'community/$spec');
    }
  }

  String _resolveUrl(String path) {
    // In real app: support ipfs://, github.com/user/repo, etc.
    return '$registryBase/$path.sprout.zip';
  }

  Future<Directory> _getPackageDir(String name) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'packages', name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  bool isInstalled(String name) {
    // Check if package dir exists
    return true;
  }
}