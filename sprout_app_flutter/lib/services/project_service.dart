import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../generated_bridge.dart' as bridge;

class ProjectService {
  static final ProjectService _instance = ProjectService._internal();
  factory ProjectService() => _instance;
  ProjectService._internal();

  late Directory _projectsDir;
  late Directory _backupsDir;
  bool _initialized = false;
  final ValueNotifier<int> projectChanges = ValueNotifier<int>(0);

  @visibleForTesting
  Future<void> useStorageDirectoryForTesting(Directory root) async {
    _projectsDir = Directory('${root.path}/sprout_projects');
    _backupsDir = Directory('${root.path}/sprout_backups');
    await _projectsDir.create(recursive: true);
    await _backupsDir.create(recursive: true);
    _initialized = true;
  }

  @visibleForTesting
  void resetStorageDirectoryForTesting() {
    _initialized = false;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _projectsDir = Directory('${appDir.path}/sprout_projects');
      _backupsDir = Directory('${appDir.path}/sprout_backups');

      await _projectsDir.create(recursive: true);
      await _backupsDir.create(recursive: true);

      _initialized = true;
    } catch (e) {
      throw ProjectException('Failed to initialize project service: $e');
    }
  }

  Future<List<String>> loadProjectNames() async {
    try {
      await _ensureInitialized();

      final entities = await _projectsDir.list(followLinks: false).toList();
      final projects = <String>[];
      for (final entity in entities) {
        if (entity is! Directory) continue;
        final displayName = await _recoverProjectIdentity(entity);
        if (displayName != null) projects.add(displayName);
      }

      projects.sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
      return projects;
    } catch (e) {
      throw ProjectException('Failed to load projects: $e');
    }
  }

  /// A project with a readable source file is recoverable even if an earlier
  /// interrupted write left its metadata absent or malformed. This prevents an
  /// existing project from becoming invisible while still preserving the safe
  /// directory-derived identifier used by all file operations.
  Future<String?> _recoverProjectIdentity(Directory projectDir) async {
    final identifier = _sanitizeName(projectDir.uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .lastOrNull ??
        '');
    if (identifier.isEmpty) return null;

    final mainFile = File('${projectDir.path}/main.sprout');
    if (!await mainFile.exists()) return null;

    final metaFile = File('${projectDir.path}/project.json');
    Map<String, dynamic>? metadata;
    try {
      if (await metaFile.exists()) {
        final decoded = jsonDecode(await metaFile.readAsString());
        if (decoded is Map<String, dynamic>) metadata = decoded;
        if (decoded is Map && metadata == null) {
          metadata = decoded.map((key, value) => MapEntry('$key', value));
        }
      }
    } catch (_) {
      metadata = null;
    }

    final storedName = metadata?['name'];
    final displayName = storedName is String &&
            storedName.trim().isNotEmpty &&
            _sanitizeName(storedName) == identifier
        ? storedName.trim()
        : identifier;

    if (metadata == null || metadata['sanitized_name'] != identifier) {
      final source = await mainFile.readAsString();
      await _writeJsonAtomically(metaFile, {
        ...?metadata,
        'name': displayName,
        'sanitized_name': identifier,
        'created': metadata?['created'] ?? DateTime.now().toIso8601String(),
        'last_recovered': DateTime.now().toIso8601String(),
        'version': metadata?['version'] ?? '1.0.0',
        'sprout_version': metadata?['sprout_version'] ?? '0.1.0',
        'security_level': metadata?['security_level'] ?? 'strict',
        'checksum': _calculateFileChecksum(source),
      });
    }

    return displayName;
  }

  Future<void> createProject(String name) async {
    try {
      await _ensureInitialized();

      final sanitized = _sanitizeName(name);
      if (sanitized.isEmpty || sanitized.length < 2) {
        throw ProjectException('Invalid project name');
      }

      final projectDir = Directory('${_projectsDir.path}/$sanitized');

      if (await projectDir.exists()) {
        throw ProjectException('Project already exists');
      }

      await projectDir.create();

      // Create main.sprout with secure template
      final mainFile = File('${projectDir.path}/main.sprout');
      await mainFile.writeAsString(_getSecureProjectTemplate(sanitized));

      // Create project metadata
      final metaFile = File('${projectDir.path}/project.json');
      final metadata = {
        'name': name,
        'sanitized_name': sanitized,
        'created': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'sprout_version': '0.1.0',
        'security_level': 'strict',
        'checksum': _calculateFileChecksum(await mainFile.readAsString()),
      };
      await _writeJsonAtomically(metaFile, metadata);

      // Create .gitignore for security
      final gitignoreFile = File('${projectDir.path}/.gitignore');
      await gitignoreFile.writeAsString(_getSecureGitignore());

      // Create README
      final readmeFile = File('${projectDir.path}/README.md');
      await readmeFile.writeAsString(_getProjectReadme(name));
      _notifyProjectChange();
    } catch (e) {
      throw ProjectException('Failed to create project: $e');
    }
  }

  Future<String> readFile(String projectName, String fileName) async {
    try {
      await _ensureInitialized();

      final sanitizedProject = _sanitizeName(projectName);
      final sanitizedFile = _sanitizeFileName(fileName);

      if (!_isValidFileName(sanitizedFile)) {
        throw ProjectException('Invalid file name: $fileName');
      }

      final file =
          File('${_projectsDir.path}/$sanitizedProject/$sanitizedFile');

      if (!await file.exists()) {
        throw ProjectException('File not found: $fileName');
      }

      // Verify file is within project directory (security check)
      if (!_isPathSafe(file.path, _projectsDir.path)) {
        throw ProjectException('Access denied: unsafe file path');
      }

      final content = await file.readAsString();

      // Verify file integrity for critical files
      if (fileName == 'main.sprout') {
        await _verifyFileIntegrity(sanitizedProject, content);
      }

      return content;
    } catch (e) {
      throw ProjectException('Failed to read file: $e');
    }
  }

  Future<void> writeFile(
      String projectName, String fileName, String content) async {
    try {
      await _ensureInitialized();

      final sanitizedProject = _sanitizeName(projectName);
      final sanitizedFile = _sanitizeFileName(fileName);

      if (!_isValidFileName(sanitizedFile)) {
        throw ProjectException('Invalid file name: $fileName');
      }

      final projectDir = Directory('${_projectsDir.path}/$sanitizedProject');

      if (!await projectDir.exists()) {
        throw ProjectException('Project does not exist');
      }

      // Validate content security
      if (fileName == 'main.sprout') {
        _validateSproutCode(content);
      }

      final file = File('${projectDir.path}/$sanitizedFile');

      // Create backup before writing
      if (await file.exists()) {
        await _createBackup(
            sanitizedProject, sanitizedFile, await file.readAsString());
      }

      await file.writeAsString(content);

      // Update project metadata
      await _updateProjectMetadata(sanitizedProject, {
        'last_modified': DateTime.now().toIso8601String(),
        'checksum': _calculateFileChecksum(content),
      });
      _notifyProjectChange();
    } catch (e) {
      throw ProjectException('Failed to write file: $e');
    }
  }

  Future<List<int>> compileCode(String code) async {
    try {
      // Comprehensive input validation
      if (code.trim().isEmpty) {
        throw CompileException('Source code cannot be empty');
      }

      if (code.length > 500000) {
        // 500KB limit
        throw CompileException('Source code too large (max 500KB)');
      }

      // Security validation
      _validateSproutCode(code);

      // Use bridge to compile with error handling
      try {
        final result = bridge
            .getCompiler()
            .compileSproutScript(code)
            .codeUnits; // Assuming it returns a string that we convert to bytes

        if (result.isEmpty) {
          throw CompileException('Compilation failed - no output generated');
        }

        // Validate compiled output
        if (result.length < 10) {
          // Minimum viable WASM size
          throw CompileException('Compilation output too small');
        }

        return result;
      } catch (e) {
        throw CompileException('Rust compilation error: $e');
      }
    } catch (e) {
      if (e is CompileException) rethrow;
      throw CompileException('Compilation failed: $e');
    }
  }

  /// Reads a project-owned, JSON-safe application state snapshot. A missing
  /// snapshot is expected for older projects and simply represents first run.
  Future<Map<String, dynamic>> readAppState(String projectName) async {
    try {
      await _ensureInitialized();
      final sanitized = _sanitizeName(projectName);
      final file = File('${_projectsDir.path}/$sanitized/app_state.json');
      if (!await file.exists()) return <String, dynamic>{};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return <String, dynamic>{};
      final container = decoded['state'];
      if (container is! Map) return <String, dynamic>{};
      return container.map((key, value) => MapEntry('$key', value));
    } catch (_) {
      // State recovery must never make source projects inaccessible.
      return <String, dynamic>{};
    }
  }

  /// Saves state atomically in the project directory. The size limit prevents a
  /// local preview from consuming storage accidentally while preserving privacy.
  Future<void> writeAppState(
    String projectName,
    Map<String, dynamic> state,
  ) async {
    try {
      await _ensureInitialized();
      final sanitized = _sanitizeName(projectName);
      final projectDir = Directory('${_projectsDir.path}/$sanitized');
      if (!await projectDir.exists()) {
        throw ProjectException('Project does not exist');
      }
      final encoded = jsonEncode(state);
      if (encoded.length > 200000) {
        throw ProjectException('App data is too large to save locally');
      }
      await _writeJsonAtomically(
        File('${projectDir.path}/app_state.json'),
        {
          'schema_version': 1,
          'updated_at': DateTime.now().toIso8601String(),
          'state': state,
        },
      );
    } catch (error) {
      if (error is ProjectException) rethrow;
      throw ProjectException('Could not save app data: $error');
    }
  }

  Future<void> clearAppState(String projectName) async {
    await _ensureInitialized();
    final sanitized = _sanitizeName(projectName);
    final file = File('${_projectsDir.path}/$sanitized/app_state.json');
    if (await file.exists()) await file.delete();
  }

  Future<ProjectMetadata> getProjectMetadata(String projectName) async {
    try {
      await _ensureInitialized();

      final sanitized = _sanitizeName(projectName);
      final metaFile = File('${_projectsDir.path}/$sanitized/project.json');

      if (!await metaFile.exists()) {
        throw ProjectException('Project metadata not found');
      }

      final content = await metaFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      return ProjectMetadata.fromJson(json);
    } catch (e) {
      throw ProjectException('Failed to read project metadata: $e');
    }
  }

  Future<void> deleteProject(String projectName) async {
    try {
      await _ensureInitialized();

      final sanitized = _sanitizeName(projectName);
      final projectDir = Directory('${_projectsDir.path}/$sanitized');

      if (!await projectDir.exists()) {
        throw ProjectException('Project does not exist');
      }

      // Create final backup before deletion
      final backupDir = Directory(
          '${_backupsDir.path}/${sanitized}_deleted_${DateTime.now().millisecondsSinceEpoch}');
      await backupDir.create(recursive: true);

      await _copyDirectory(projectDir, backupDir);

      // Delete project
      await projectDir.delete(recursive: true);
      _notifyProjectChange();
    } catch (e) {
      throw ProjectException('Failed to delete project: $e');
    }
  }

  // Security validation methods
  void _validateSproutCode(String code) {
    final dangerousPatterns = [
      RegExp(r'import\s+'), // Block imports
      RegExp(r'eval\s*\('), // Block eval
      RegExp(r'exec\s*\('), // Block exec
      RegExp(r'system\s*\('), // Block system calls
      RegExp(r'__[a-zA-Z_]+__'), // Block dunder methods
      RegExp(r'\.\.\/'), // Block path traversal
      RegExp(r'file\s*\('), // Block direct file access
      RegExp(r'open\s*\('), // Block open calls
      RegExp(r'subprocess'), // Block subprocess
    ];

    for (final pattern in dangerousPatterns) {
      if (pattern.hasMatch(code)) {
        throw SecurityException(
            'Dangerous code pattern detected: ${pattern.pattern}');
      }
    }

    // Check for suspicious URLs
    final urlPattern = RegExp(r'https?:\/\/[^\s]+');
    if (urlPattern.hasMatch(code)) {
      throw SecurityException('External URLs not allowed in strict mode');
    }
  }

  void _notifyProjectChange() {
    projectChanges.value++;
  }

  String _sanitizeName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\.\.'), '')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
    return cleaned.substring(0, cleaned.length.clamp(0, 50));
  }

  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\.\.'), '')
        .trim();
  }

  bool _isValidFileName(String fileName) {
    final allowedExtensions = ['sprout', 'json', 'md', 'txt'];
    final extension = fileName.split('.').last.toLowerCase();

    return RegExp(r'^[a-zA-Z0-9._-]+$')
            .hasMatch(fileName.replaceAll('.', '')) &&
        allowedExtensions.contains(extension) &&
        !fileName.startsWith('.') &&
        fileName.length <= 255;
  }

  bool _isPathSafe(String filePath, String basePath) {
    final resolvedFile = File(filePath).absolute.path;
    final resolvedBase = Directory(basePath).absolute.path;
    return resolvedFile.startsWith(resolvedBase);
  }

  String _calculateFileChecksum(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _verifyFileIntegrity(String projectName, String content) async {
    try {
      final metadata = await getProjectMetadata(projectName);
      final currentChecksum = _calculateFileChecksum(content);

      if (metadata.checksum != null && metadata.checksum != currentChecksum) {
        // File has been modified outside the app
        // For now, just update the checksum - in production, might want to alert user
        await _updateProjectMetadata(projectName, {
          'checksum': currentChecksum,
          'integrity_warning': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // Ignore integrity check failures for now
    }
  }

  Future<void> _createBackup(
      String projectName, String fileName, String content) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupDir = Directory('${_backupsDir.path}/$projectName');
      await backupDir.create(recursive: true);

      final backupFile =
          File('${backupDir.path}/${fileName}_$timestamp.backup');
      await backupFile.writeAsString(content);

      // Keep only last 10 backups per file
      await _cleanupBackups(backupDir, fileName);
    } catch (e) {
      // Ignore backup failures
    }
  }

  Future<void> _cleanupBackups(Directory backupDir, String fileName) async {
    try {
      final backups = await backupDir
          .list()
          .where((entity) =>
              entity.path.contains(fileName) && entity.path.endsWith('.backup'))
          .cast<File>()
          .toList();

      if (backups.length > 10) {
        backups.sort(
            (a, b) => a.statSync().changed.compareTo(b.statSync().changed));

        for (int i = 0; i < backups.length - 10; i++) {
          await backups[i].delete();
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  Future<void> _updateProjectMetadata(
      String projectName, Map<String, dynamic> updates) async {
    try {
      final metaFile = File('${_projectsDir.path}/$projectName/project.json');

      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        json.addAll(updates);
        await _writeJsonAtomically(metaFile, json);
      }
    } catch (e) {
      // Ignore metadata update failures
    }
  }

  Future<void> _writeJsonAtomically(
    File destination,
    Map<String, dynamic> data,
  ) async {
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(jsonEncode(data), flush: true);
    await temporary.rename(destination.path);
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDirectory =
            Directory('${destination.path}/${entity.path.split('/').last}');
        await newDirectory.create();
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        await entity.copy('${destination.path}/${entity.path.split('/').last}');
      }
    }
  }

  String _getSecureProjectTemplate(String name) {
    return '''// Sprout App: $name
// Generated: ${DateTime.now().toIso8601String()}
// Security Level: Strict

app "$name" {
  start = "Home"
  version = "1.0.0"
}

screen Home {
  state message = "Hello, $name!"
  state count = 0
  state isEnabled = true

  ui {
    column {
      title "\${message}"
      
      label "Welcome to your Sprout app!"
      label "Count: \${count}"
      
      row {
        button "Increment" {
          count = count + 1
          message = "Count updated!"
        }
        
        button "Reset" {
          count = 0
          message = "Reset complete"
        }
      }
      
      if isEnabled {
        button "Disable Counter" {
          isEnabled = false
          message = "Counter disabled"
        }
      } else {
        button "Enable Counter" {
          isEnabled = true  
          message = "Counter enabled"
        }
      }
      
      button "About" {
        -> About
      }
    }
  }
}

screen About {
  ui {
    column {
      title "About $name"
      
      label "This is a Sprout application."
      label "Built with security and privacy in mind."
      label "All code runs locally on your device."
      
      button "Back to Home" {
        -> Home
      }
    }
  }
}
''';
  }

  String _getSecureGitignore() {
    return '''# Sprout Security - Do not commit these files
*.key
*.keystore
*.p12
*.pem
secrets/
.env
.env.local
*.log

# Backup files
*.backup
*~

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db
''';
  }

  String _getProjectReadme(String name) {
    return '''# $name

A Sprout application - grow apps that grow with you.

## 🌱 About

This app was created using Sprout, a secure, privacy-first mobile development platform.

### Key Features:
- ✅ Runs entirely on your device
- ✅ No data collection or tracking  
- ✅ Open source and auditable
- ✅ Secure by design

## 🔒 Security

This project follows Sprout security best practices:
- All code execution is sandboxed
- No external network access
- File system access is restricted
- Input validation and sanitization

## 🛠️ Development

Open this project in the Sprout app to edit and run it.

### Project Structure:
- `main.sprout` - Main application code
- `project.json` - Project metadata
- `README.md` - This file

---

Built with ❤️ using Sprout
''';
  }
}

// Secure installation service
class InstallService {
  static Future<void> installApp(String projectName) async {
    try {
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(projectName)) {
        throw InstallException('Invalid project name for installation');
      }

      final projectService = ProjectService();

      // Read and validate project
      final code = await projectService.readFile(projectName, 'main.sprout');

      // Compile with security checks
      final wasm = await projectService.compileCode(code);

      if (wasm.isEmpty) {
        throw InstallException('Compilation failed');
      }

      // Create local APK structure (backend-free approach)
      await _createLocalInstallation(projectName, wasm);
    } catch (e) {
      throw InstallException('Installation failed: $e');
    }
  }

  static Future<void> _createLocalInstallation(
      String projectName, List<int> wasm) async {
    // This would create a local app structure that can be "installed"
    // For now, simulate the process
    await Future.delayed(const Duration(seconds: 2));

    // In a real implementation, this could:
    // 1. Create an Android APK structure locally
    // 2. Use platform-specific installation APIs
    // 3. Register the app with the system launcher
  }
}

// Data models
class ProjectMetadata {
  final String name;
  final String? sanitizedName;
  final DateTime created;
  final String version;
  final String sproutVersion;
  final String securityLevel;
  final String? checksum;
  final DateTime? lastModified;
  final String? integrityWarning;

  ProjectMetadata({
    required this.name,
    this.sanitizedName,
    required this.created,
    required this.version,
    required this.sproutVersion,
    required this.securityLevel,
    this.checksum,
    this.lastModified,
    this.integrityWarning,
  });

  factory ProjectMetadata.fromJson(Map<String, dynamic> json) {
    return ProjectMetadata(
      name: json['name'] as String,
      sanitizedName: json['sanitized_name'] as String?,
      created: DateTime.parse(json['created'] as String),
      version: json['version'] as String,
      sproutVersion: json['sprout_version'] as String,
      securityLevel: json['security_level'] as String? ?? 'strict',
      checksum: json['checksum'] as String?,
      lastModified: json['last_modified'] != null
          ? DateTime.parse(json['last_modified'] as String)
          : null,
      integrityWarning: json['integrity_warning'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sanitized_name': sanitizedName,
      'created': created.toIso8601String(),
      'version': version,
      'sprout_version': sproutVersion,
      'security_level': securityLevel,
      'checksum': checksum,
      'last_modified': lastModified?.toIso8601String(),
      'integrity_warning': integrityWarning,
    };
  }
}

// Custom exceptions
class ProjectException implements Exception {
  final String message;
  ProjectException(this.message);

  @override
  String toString() => 'ProjectException: $message';
}

class CompileException implements Exception {
  final String message;
  CompileException(this.message);

  @override
  String toString() => 'CompileException: $message';
}

class InstallException implements Exception {
  final String message;
  InstallException(this.message);

  @override
  String toString() => 'InstallException: $message';
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}
