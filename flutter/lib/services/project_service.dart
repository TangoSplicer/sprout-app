// flutter/lib/services/project_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import '../../bridge/bridge.dart';
import '../models/project.dart';

class ProjectService {
  static final ProjectService _instance = ProjectService._internal();
  final _uuid = const Uuid();

  // Singleton access
  factory ProjectService() => _instance;
  ProjectService._internal();

  // Cache of loaded projects
  List<SproutProject> _projects = [];

  /// Get the root directory for all Sprout projects
  Future<Directory> _getProjectsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'sprout_projects'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Create a new project with name and default main.sprout
  Future<void> createProject(String name) async {
    final root = await _getProjectsDir();
    final projectDir = Directory(p.join(root.path, _sanitizeName(name)));
    if (await projectDir.exists()) {
      throw Exception('A project named "$name" already exists.');
    }
    await projectDir.create();

    final mainFile = File(p.join(projectDir.path, 'main.sprout'));
    await mainFile.writeAsString('''
app "$name" {
  start = Home
}

screen Home {
  state count = 0

  ui {
    column {
      title("Tap to grow")
      label("\${count}")
      button("++") {
        count = count + 1
      }
    }
  }
}
''');

    final project = SproutProject(
      name: name,
      path: projectDir.path,
      files: ['main.sprout'],
    );
    _projects.add(project);
  }

  /// Load all project names from disk
  Future<List<String>> loadProjectNames() async {
    final dir = await _getProjectsDir();
    if (!await dir.exists()) return [];
    final entities = dir.listSync();
    final projectNames = <String>[];
    for (var e in entities) {
      if (e is Directory) {
        final name = p.basename(e.path);
        if (!_projects.any((p) => p.name == name)) {
          _projects.add(SproutProject(
            name: name,
            path: e.path,
            files: await _getFilesInDir(e),
          ));
        }
        projectNames.add(name);
      }
    }
    return projectNames;
  }

  /// Get all files in a project directory
  Future<List<String>> _getFilesInDir(Directory dir) async {
    final list = await dir.list().toList();
    return list
        .where((e) => e is File)
        .map((e) => p.basename(e.path))
        .where((name) => name.endsWith('.sprout'))
        .toList();
  }

  /// Read a file from a project
  Future<String> readFile(String projectName, String fileName) async {
    final filePath = await _resolveFilePath(projectName, fileName);
    final file = File(filePath);
    if (await file.exists()) {
      return file.readAsString();
    } else {
      throw Exception('File not found: $fileName');
    }
  }

  /// Write a file in a project
  Future<void> writeFile(String projectName, String fileName, String content) async {
    final filePath = await _resolveFilePath(projectName, fileName);
    final file = File(filePath);
    await file.writeAsString(content);
    _updateProjectModified(projectName);
  }

  /// Resolve full path to a file in a project
  Future<String> _resolveFilePath(String projectName, String fileName) async {
    final projectDir = Directory(p.join((await _getProjectsDir()).path, _sanitizeName(projectName)));
    return p.join(projectDir.path, fileName);
  }

  /// Update project last modified time
  void _updateProjectModified(String projectName) {
    final project = _projects.firstWhere((p) => p.name == projectName, orElse: () => throw Exception('Project not found'));
    final index = _projects.indexOf(project);
    _projects[index] = SproutProject(
      name: project.name,
      path: project.path,
      createdAt: project.createdAt,
      lastModified: DateTime.now(),
      files: project.files,
    );
  }

  /// Compile SproutScript to WASM bytecode via Rust
  Future<Uint8List> compileCode(String source) async {
    try {
      final wasmBytes = await rustBridge.compileToWasm(source);
      return wasmBytes;
    } on Exception catch (e) {
      print("❌ Compilation failed: $e");
      return Uint8List(0);
    }
  }

  /// Optional: Parse and return AST dump for debugging
  Future<String> parseToAst(String source) async {
    try {
      return await rustBridge.parseToAst(source);
    } on Exception catch (e) {
      return "Parse error: $e";
    }
  }

  /// List all files in a project
  Future<List<String>> listFiles(String projectName) async {
    final dir = Directory(await _resolveFilePath(projectName, '.'));
    if (!await dir.exists()) return [];
    return (await dir.list().toList())
        .whereType<File>()
        .map((file) => p.basename(file.path))
        .where((name) => name.endsWith('.sprout'))
        .toList();
  }

  /// Delete a project
  Future<void> deleteProject(String projectName) async {
    final dir = Directory(p.join((await _getProjectsDir()).path, _sanitizeName(projectName)));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      _projects.removeWhere((p) => p.name == projectName);
    }
  }

  /// Rename a project
  Future<void> renameProject(String oldName, String newName) async {
    final oldDir = Directory(p.join((await _getProjectsDir()).path, _sanitizeName(oldName)));
    final newDir = Directory(p.join((await _getProjectsDir()).path, _sanitizeName(newName)));
    if (await newDir.exists()) {
      throw Exception('A project named "$newName" already exists.');
    }
    await oldDir.rename(newDir.path);
    _projects.removeWhere((p) => p.name == oldName);
    _projects.add(SproutProject(
      name: newName,
      path: newDir.path,
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      files: await listFiles(newName),
    ));
  }

  /// Sanitize project name for filesystem
  String _sanitizeName(String name) {
    return name.replaceAll(RegExp(r'[^\w\-. ]'), '_');
  }

  /// Get project by name
  SproutProject? getProject(String name) {
    return _projects.firstWhereOrNull((p) => p.name == name);
  }
}

// Helper for null-aware firstWhere
extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}