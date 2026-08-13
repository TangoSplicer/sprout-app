import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class PackageManager {
  static final PackageManager _instance = PackageManager._internal();
  static final RegExp _packageNamePattern =
      RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');
  static const _maximumArchiveBytes = 10 * 1024 * 1024;

  factory PackageManager() => _instance;

  PackageManager._internal();

  final Uri registryBase = Uri.parse('https://pkg.sprout.garden');

  Future<void> installPackage(String spec) async {
    final package = _parseSpec(spec);
    final response = await http
        .get(_resolveUri(package.source))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
          'Package registry returned HTTP ${response.statusCode}');
    }
    if (response.bodyBytes.length > _maximumArchiveBytes) {
      throw const FormatException('Package archive exceeds the 10 MiB limit');
    }

    final archive = ZipDecoder().decodeBytes(response.bodyBytes, verify: true);
    final packageDirectory = await _getPackageDir(package.name);
    final stagingDirectory = Directory('${packageDirectory.path}.staging');
    if (await stagingDirectory.exists()) {
      await stagingDirectory.delete(recursive: true);
    }
    await stagingDirectory.create(recursive: true);

    try {
      for (final file in archive) {
        if (!file.isFile) continue;
        final destination =
            _safeArchiveDestination(stagingDirectory, file.name);
        await destination.parent.create(recursive: true);
        await destination.writeAsBytes(file.content as List<int>, flush: true);
      }

      if (await packageDirectory.exists()) {
        await packageDirectory.delete(recursive: true);
      }
      await stagingDirectory.rename(packageDirectory.path);
    } catch (_) {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  _PackageSpec _parseSpec(String spec) {
    final normalized = spec.trim();
    final source = normalized.startsWith('@sprout/')
        ? 'official/${normalized.substring('@sprout/'.length)}'
        : normalized.contains('/')
            ? 'community/$normalized'
            : 'community/$normalized';
    final name = source.split('/').last;
    if (!_packageNamePattern.hasMatch(name)) {
      throw ArgumentError.value(spec, 'spec', 'Invalid package name');
    }
    return _PackageSpec(name: name, source: source);
  }

  Uri _resolveUri(String source) {
    return registryBase.resolve('${Uri.encodeFull(source)}.sprout.zip');
  }

  Future<Directory> _getPackageDir(String name) async {
    final appDirectory = await getApplicationDocumentsDirectory();
    return Directory(path.join(appDirectory.path, 'packages', name));
  }

  File _safeArchiveDestination(Directory root, String archivePath) {
    final candidate = path.normalize(path.join(root.path, archivePath));
    if (!path.isWithin(root.path, candidate)) {
      throw const FormatException('Package archive contains an unsafe path');
    }
    return File(candidate);
  }

  Future<bool> isInstalled(String name) async {
    if (!_packageNamePattern.hasMatch(name)) return false;
    return (await _getPackageDir(name)).exists();
  }
}

class _PackageSpec {
  final String name;
  final String source;

  const _PackageSpec({required this.name, required this.source});
}
