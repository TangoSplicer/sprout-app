import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'project_service.dart';

/// A portable, offline-first Sprout app package.
///
/// Package files use the `.sproutapp` extension and contain a gzip-compressed
/// tar archive. The archive has exactly three application-owned entries:
/// `manifest.json`, `main.sprout`, and the optional `app_state.json`.
/// Foreign project metadata is intentionally not imported; every device creates
/// fresh local metadata, backups, checksums, and storage identifiers.
class SproutAppPackageService {
  static const format = 'sprout.app.package';
  static const schemaVersion = 1;
  static const fileExtension = '.sproutapp';
  static const mimeType = 'application/vnd.sprout.app+gzip';
  static const maxPackageBytes = 2 * 1024 * 1024;
  static const maxSourceBytes = 500 * 1024;
  static const maxStateBytes = 200 * 1024;
  static const _manifestFile = 'manifest.json';
  static const _sourceFile = 'main.sprout';
  static const _stateFile = 'app_state.json';
  static const _uuid = Uuid();

  final ProjectService _projects;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  SproutAppPackageService({
    ProjectService? projects,
    Future<Directory> Function()? temporaryDirectoryProvider,
  })  : _projects = projects ?? ProjectService(),
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory;

  /// Exports a complete portable app snapshot. Source is always included; local
  /// app data is opt-in because it may contain the creator's private entries.
  Future<SproutPackageExport> exportProject(
    String projectName, {
    bool includeAppState = false,
  }) async {
    final source = await _projects.readFile(projectName, _sourceFile);
    final state = includeAppState
        ? await _projects.readAppState(projectName)
        : <String, dynamic>{};
    final bytes = buildPackageBytes(
      projectName: projectName,
      source: source,
      appState: state,
      includesAppState: includeAppState && state.isNotEmpty,
    );
    final directory = await _temporaryDirectoryProvider();
    final fileName =
        '${_safeExportStem(projectName)}-${DateTime.now().millisecondsSinceEpoch}$fileExtension';
    final packageFile = File(path.join(directory.path, fileName));
    await packageFile.writeAsBytes(bytes, flush: true);
    return SproutPackageExport(
      file: packageFile,
      manifest: inspectBytes(bytes).manifest,
    );
  }

  /// Builds a package in memory for QR, nearby, and platform-share transports.
  /// It is deliberately deterministic except for package ID and timestamp.
  Uint8List buildPackageBytes({
    required String projectName,
    required String source,
    Map<String, dynamic> appState = const {},
    bool includesAppState = false,
  }) {
    final sourceBytes = Uint8List.fromList(utf8.encode(source));
    if (sourceBytes.length > maxSourceBytes) {
      throw const SproutPackageException(
          'The app source is too large to share.');
    }
    final stateBytes = Uint8List.fromList(utf8.encode(jsonEncode(appState)));
    if (includesAppState && stateBytes.length > maxStateBytes) {
      throw const SproutPackageException('The app data is too large to share.');
    }

    final manifest = SproutPackageManifest(
      packageId: _uuid.v4(),
      projectName: projectName.trim(),
      createdAt: DateTime.now().toUtc(),
      includesAppState: includesAppState,
      sourceSha256: sha256.convert(sourceBytes).toString(),
      stateSha256:
          includesAppState ? sha256.convert(stateBytes).toString() : null,
    );
    final archive = Archive()
      ..addFile(ArchiveFile(
        _manifestFile,
        utf8.encode(jsonEncode(manifest.toJson())).length,
        utf8.encode(jsonEncode(manifest.toJson())),
      ))
      ..addFile(ArchiveFile(_sourceFile, sourceBytes.length, sourceBytes));
    if (includesAppState) {
      archive.addFile(ArchiveFile(_stateFile, stateBytes.length, stateBytes));
    }
    final tar = TarEncoder().encode(archive);
    final compressed = GZipEncoder().encode(tar);
    if (compressed.length > maxPackageBytes) {
      throw const SproutPackageException(
          'The complete app package is too large to share.');
    }
    return Uint8List.fromList(compressed);
  }

  SproutPackagePreview inspectFile(File file) =>
      inspectBytes(file.readAsBytesSync());

  SproutPackagePreview inspectBytes(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxPackageBytes) {
      throw const SproutPackageException(
          'This app package is empty or exceeds Sprout’s safety limit.');
    }
    late Archive archive;
    try {
      archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    } catch (_) {
      throw const SproutPackageException(
          'This is not a valid Sprout app package.');
    }
    if (archive.files.length < 2 || archive.files.length > 3) {
      throw const SproutPackageException(
          'The package contains an unsupported number of files.');
    }
    final files = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (!file.isFile ||
          !_isAllowedPackagePath(file.name) ||
          files.containsKey(file.name)) {
        throw const SproutPackageException(
            'The package contains an unsafe or duplicate file.');
      }
      files[file.name] = file;
    }
    final manifestFile = files[_manifestFile];
    final sourceFile = files[_sourceFile];
    if (manifestFile == null || sourceFile == null) {
      throw const SproutPackageException(
          'The package must contain a manifest and Sprout source.');
    }
    final manifest =
        SproutPackageManifest.fromJson(_decodeJsonFile(manifestFile));
    final sourceBytes = _archiveBytes(sourceFile);
    if (sourceBytes.length > maxSourceBytes ||
        sha256.convert(sourceBytes).toString() != manifest.sourceSha256) {
      throw const SproutPackageException(
          'The project source did not pass package integrity checks.');
    }
    final source = utf8.decode(sourceBytes, allowMalformed: false);
    _validateSourceEnvelope(source);
    final stateFile = files[_stateFile];
    if (manifest.includesAppState != (stateFile != null)) {
      throw const SproutPackageException(
          'The package state declaration does not match its contents.');
    }
    Map<String, dynamic> appState = <String, dynamic>{};
    if (stateFile != null) {
      final stateBytes = _archiveBytes(stateFile);
      if (stateBytes.length > maxStateBytes ||
          sha256.convert(stateBytes).toString() != manifest.stateSha256) {
        throw const SproutPackageException(
            'The shared app data did not pass integrity checks.');
      }
      final decoded = _decodeJsonBytes(stateBytes);
      if (decoded is! Map) {
        throw const SproutPackageException(
            'The shared app data must be a JSON object.');
      }
      appState = decoded.map((key, value) => MapEntry('$key', value));
    }
    return SproutPackagePreview(
      manifest: manifest,
      source: source,
      appState: appState,
    );
  }

  /// Imports a package without ever overwriting an existing project. A shared
  /// app receives a fresh local project identity and automatically gains a
  /// numbered copy name on collision.
  Future<SproutPackageImport> importFile(
    File file, {
    String? preferredName,
  }) async {
    final preview = inspectFile(file);
    final chosenName = await _availableProjectName(
      _normaliseName(preferredName ?? preview.manifest.projectName),
    );
    await _projects.createProject(chosenName);
    try {
      await _projects.writeFile(chosenName, _sourceFile, preview.source);
      if (preview.manifest.includesAppState && preview.appState.isNotEmpty) {
        await _projects.writeAppState(chosenName, preview.appState);
      }
    } catch (error) {
      await _projects.deleteProject(chosenName);
      rethrow;
    }
    return SproutPackageImport(
      projectName: chosenName,
      manifest: preview.manifest,
      includedAppState: preview.manifest.includesAppState,
    );
  }

  Future<String> _availableProjectName(String requested) async {
    final existing = (await _projects.loadProjectNames())
        .map((name) => name.toLowerCase())
        .toSet();
    if (!existing.contains(requested.toLowerCase())) return requested;
    for (var index = 2; index <= 99; index++) {
      final candidate = '$requested $index';
      if (!existing.contains(candidate.toLowerCase())) return candidate;
    }
    throw const SproutPackageException(
        'Too many apps with this name already exist.');
  }

  String _normaliseName(String value) {
    final collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length >= 2) {
      return collapsed.substring(0, collapsed.length.clamp(2, 60));
    }
    return 'Shared Sprout app';
  }

  String _safeExportStem(String name) {
    final stem = name
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return stem.isEmpty
        ? 'sprout-app'
        : stem.substring(0, stem.length.clamp(1, 48));
  }

  static bool _isAllowedPackagePath(String name) =>
      name == _manifestFile || name == _sourceFile || name == _stateFile;

  static void _validateSourceEnvelope(String source) {
    if (source.trim().isEmpty ||
        !RegExp(r'^\s*app\s+"[^"]+"\s*\{', multiLine: true).hasMatch(source) ||
        !RegExp(r'^\s*screen\s+[A-Za-z_]\w*\s*\{', multiLine: true)
            .hasMatch(source)) {
      throw const SproutPackageException(
        'The package source is not a complete Sprout app.',
      );
    }
  }

  static List<int> _archiveBytes(ArchiveFile file) {
    return file.content as List<int>;
  }

  static Map<String, dynamic> _decodeJsonFile(ArchiveFile file) {
    return _decodeJsonBytes(_archiveBytes(file)) as Map<String, dynamic>;
  }

  static dynamic _decodeJsonBytes(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } catch (_) {
      throw const SproutPackageException(
          'A package JSON file could not be read.');
    }
  }
}

class SproutPackageManifest {
  final String packageId;
  final String projectName;
  final DateTime createdAt;
  final bool includesAppState;
  final String sourceSha256;
  final String? stateSha256;

  const SproutPackageManifest({
    required this.packageId,
    required this.projectName,
    required this.createdAt,
    required this.includesAppState,
    required this.sourceSha256,
    required this.stateSha256,
  });

  factory SproutPackageManifest.fromJson(Map<String, dynamic> json) {
    if (json['format'] != SproutAppPackageService.format ||
        json['schema_version'] != SproutAppPackageService.schemaVersion ||
        json['package_id'] is! String ||
        json['project_name'] is! String ||
        json['created_at'] is! String ||
        json['includes_app_state'] is! bool ||
        json['source_sha256'] is! String) {
      throw const SproutPackageException(
          'The package manifest is unsupported or incomplete.');
    }
    final packageId = json['package_id'] as String;
    final projectName = json['project_name'] as String;
    final sourceSha = json['source_sha256'] as String;
    final stateSha = json['state_sha256'];
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sourceSha) ||
        packageId.length > 80 ||
        projectName.trim().length < 2 ||
        projectName.length > 120 ||
        (stateSha != null &&
            (stateSha is! String ||
                !RegExp(r'^[0-9a-f]{64}$').hasMatch(stateSha)))) {
      throw const SproutPackageException(
          'The package manifest contains invalid values.');
    }
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(json['created_at'] as String).toUtc();
    } catch (_) {
      throw const SproutPackageException(
          'The package creation date is invalid.');
    }
    final includesState = json['includes_app_state'] as bool;
    if (includesState != (stateSha is String)) {
      throw const SproutPackageException(
          'The package state metadata is inconsistent.');
    }
    return SproutPackageManifest(
      packageId: packageId,
      projectName: projectName,
      createdAt: createdAt,
      includesAppState: includesState,
      sourceSha256: sourceSha,
      stateSha256: stateSha as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': SproutAppPackageService.format,
        'schema_version': SproutAppPackageService.schemaVersion,
        'package_id': packageId,
        'project_name': projectName,
        'created_at': createdAt.toIso8601String(),
        'includes_app_state': includesAppState,
        'source_sha256': sourceSha256,
        if (stateSha256 != null) 'state_sha256': stateSha256,
      };
}

class SproutPackagePreview {
  final SproutPackageManifest manifest;
  final String source;
  final Map<String, dynamic> appState;

  const SproutPackagePreview({
    required this.manifest,
    required this.source,
    required this.appState,
  });
}

class SproutPackageExport {
  final File file;
  final SproutPackageManifest manifest;

  const SproutPackageExport({required this.file, required this.manifest});
}

class SproutPackageImport {
  final String projectName;
  final SproutPackageManifest manifest;
  final bool includedAppState;

  const SproutPackageImport({
    required this.projectName,
    required this.manifest,
    required this.includedAppState,
  });
}

class SproutPackageException implements Exception {
  final String message;

  const SproutPackageException(this.message);

  @override
  String toString() => message;
}
