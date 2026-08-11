// Project Manager Service for Sprout
// Handles project save, load, export, and encryption

import 'dart:convert';
import 'dart:io';
import 'package:secure_storage_service/secure_storage_service.dart';
import 'package:encryption_service/encryption_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

class ProjectManager {
  static final ProjectManager _instance = ProjectManager._internal();
  factory ProjectManager() => _instance;
  ProjectManager._internal();

  final SecureStorageService _secureStorage = SecureStorageService();
  final EncryptionService _encryptionService = EncryptionService();

  // Security: Project metadata
  final Map<String, ProjectMetadata> _projectMetadata = {};

  // Security: Create new project
  Future<Project> createProject(String name, String description) async {
    try {
      // Security: Validate project name
      if (name.isEmpty || name.length > 100) {
        throw ValidationException('Project name must be 1-100 characters');
      }

      // Security: Check for dangerous patterns
      if (name.contains('..') || name.contains('/') || name.contains('\\')) {
        throw ValidationException('Invalid project name');
      }

      // Security: Generate unique project ID
      final projectId = _generateProjectId(name);

      // Security: Create project structure
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final project = Project(
        id: projectId,
        name: name,
        description: description,
        createdAt: timestamp,
        updatedAt: timestamp,
        version: '1.0.0',
        code: '',
        screens: [],
        state: {},
      );

      // Security: Save project metadata
      await _saveProjectMetadata(project);

      return project;
    } catch (e) {
      throw ProjectException('Failed to create project: $e');
    }
  }

  // Security: Save project with encryption
  Future<void> saveProject(Project project, {bool encrypt = true}) async {
    try {
      // Security: Validate project
      _validateProject(project);

      // Security: Update timestamp
      project.updatedAt = DateTime.now().millisecondsSinceEpoch;

      // Security: Serialize project
      final projectJson = jsonEncode(project.toJson());

      if (encrypt) {
        // Security: Encrypt project data
        final encrypted = await _encryptionService.encryptText(projectJson);
        await _secureStorage.storeSecure('project_${project.id}', encrypted);
      } else {
        // Security: Store unencrypted (for development)
        await _secureStorage.storeSecure('project_${project.id}', projectJson);
      }

      // Security: Update metadata
      await _saveProjectMetadata(project);

      // Security: Calculate and store hash
      final hash = _calculateProjectHash(project);
      await _secureStorage.storeSecure('project_${project.id}_hash', hash);
    } catch (e) {
      throw ProjectException('Failed to save project: $e');
    }
  }

  // Security: Load and decrypt project
  Future<Project?> loadProject(String projectId, {bool encrypted = true}) async {
    try {
      // Security: Validate project ID
      if (projectId.isEmpty) {
        throw ValidationException('Invalid project ID');
      }

      // Security: Retrieve project data
      final data = await _secureStorage.getSecure('project_$projectId');

      if (data == null) {
        return null;
      }

      // Security: Verify hash
      final storedHash = await _secureStorage.getSecure('project_${projectId}_hash');
      if (storedHash != null) {
        final currentHash = await _calculateHashFromData(data);
        if (currentHash != storedHash) {
          throw SecurityException('Project data integrity check failed');
        }
      }

      String projectJson;
      if (encrypted) {
        // Security: Decrypt project data
        projectJson = await _encryptionService.decryptText(data);
      } else {
        projectJson = data;
      }

      // Security: Deserialize project
      final projectJsonMap = jsonDecode(projectJson) as Map<String, dynamic>;
      final project = Project.fromJson(projectJsonMap);

      return project;
    } catch (e) {
      throw ProjectException('Failed to load project: $e');
    }
  }

  // Security: Export project to .sprout file
  Future<String> exportProject(Project projectId, {bool encrypt = true}) async {
    try {
      // Security: Load project
      final project = await loadProject(projectId.id, encrypted: encrypt);

      if (project == null) {
        throw ProjectException('Project not found');
      }

      // Security: Serialize project
      final projectJson = jsonEncode(project.toJson());

      // Security: Create .sprout file
      final sproutFile = SproutFile(
        version: '1.0',
        projectId: project.id,
        projectName: project.name,
        createdAt: project.createdAt,
        exportedAt: DateTime.now().millisecondsSinceEpoch,
        data: projectJson,
        encrypted: encrypt,
      );

      // Security: Serialize .sprout file
      final sproutFileJson = jsonEncode(sproutFile.toJson());

      // Security: Get documents directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, '${project.name}.sprout');

      // Security: Write to file
      final file = File(filePath);
      await file.writeAsString(sproutFileJson);

      return filePath;
    } catch (e) {
      throw ProjectException('Failed to export project: $e');
    }
  }

  // Security: Import project from .sprout file
  Future<Project> importProject(String filePath, {bool encrypted = true}) async {
    try {
      // Security: Validate file path
      if (!filePath.endsWith('.sprout')) {
        throw ValidationException('Invalid file format. Expected .sprout file');
      }

      // Security: Check file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw ValidationException('File not found');
      }

      // Security: Read file
      final fileContent = await file.readAsString();

      // Security: Deserialize .sprout file
      final sproutFileJson = jsonDecode(fileContent) as Map<String, dynamic>;
      final sproutFile = SproutFile.fromJson(sproutFileJson);

      // Security: Verify version
      if (sproutFile.version != '1.0') {
        throw ValidationException('Unsupported .sprout file version');
      }

      // Security: Validate file
      if (sproutFile.encrypted != encrypted) {
        throw ValidationException('Encryption mismatch');
      }

      // Security: Deserialize project
      final projectJson = jsonDecode(sproutFile.data) as Map<String, dynamic>;
      final project = Project.fromJson(projectJson);

      // Security: Save imported project
      await saveProject(project, encrypt: encrypted);

      return project;
    } catch (e) {
      throw ProjectException('Failed to import project: $e');
    }
  }

  // Security: Delete project
  Future<void> deleteProject(String projectId) async {
    try {
      // Security: Delete project data
      await _secureStorage.deleteSecure('project_$projectId');
      await _secureStorage.deleteSecure('project_${projectId}_hash');

      // Security: Delete metadata
      await _secureStorage.deleteSecure('project_${projectId}_metadata');

      // Security: Remove from cache
      _projectMetadata.remove(projectId);
    } catch (e) {
      throw ProjectException('Failed to delete project: $e');
    }
  }

  // Security: List all projects
  Future<List<ProjectMetadata>> listProjects() async {
    try {
      final keys = await _secureStorage.getAllKeys();
      final projectKeys = keys.where((key) => key.endsWith('_metadata')).toList();

      final projects = <ProjectMetadata>[];
      for (final key in projectKeys) {
        final metadataJson = await _secureStorage.getSecure(key);
        if (metadataJson != null) {
          final metadataMap = jsonDecode(metadataJson) as Map<String, dynamic>;
          final metadata = ProjectMetadata.fromJson(metadataMap);
          projects.add(metadata);
        }
      }

      // Security: Sort by updated date
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      return projects;
    } catch (e) {
      throw ProjectException('Failed to list projects: $e');
    }
  }

  // Security: Validate project
  void _validateProject(Project project) {
    // Security: Validate project ID
    if (project.id.isEmpty) {
      throw ValidationException('Project ID is required');
    }

    // Security: Validate project name
    if (project.name.isEmpty || project.name.length > 100) {
      throw ValidationException('Project name must be 1-100 characters');
    }

    // Security: Validate code size
    if (project.code.length > 100000) { // 100KB limit
      throw ValidationException('Project code too large');
    }

    // Security: Validate screens count
    if (project.screens.length > 50) {
      throw ValidationException('Too many screens');
    }
  }

  // Security: Save project metadata
  Future<void> _saveProjectMetadata(Project project) async {
    final metadata = ProjectMetadata(
      id: project.id,
      name: project.name,
      description: project.description,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
      version: project.version,
      size: project.code.length,
    );

    final metadataJson = jsonEncode(metadata.toJson());
    await _secureStorage.storeSecure('project_${project.id}_metadata', metadataJson);

    _projectMetadata[project.id] = metadata;
  }

  // Security: Generate project ID
  String _generateProjectId(String name) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = sha256.convert(utf8.encode('$name-$timestamp'));
    return hash.toString().substring(0, 16);
  }

  // Security: Calculate project hash
  Future<String> _calculateProjectHash(Project project) async {
    final projectJson = jsonEncode(project.toJson());
    final hash = sha256.convert(utf8.encode(projectJson));
    return hash.toString();
  }

  // Security: Calculate hash from data
  Future<String> _calculateHashFromData(String data) async {
    final hash = sha256.convert(utf8.encode(data));
    return hash.toString();
  }
}

// Project model
class Project {
  String id;
  String name;
  String description;
  int createdAt;
  int updatedAt;
  String version;
  String code;
  List<dynamic> screens;
  Map<String, dynamic> state;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.code,
    required this.screens,
    required this.state,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'version': version,
      'code': code,
      'screens': screens,
      'state': state,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      version: json['version'] as String,
      code: json['code'] as String,
      screens: json['screens'] as List<dynamic>,
      state: json['state'] as Map<String, dynamic>,
    );
  }
}

// Project metadata
class ProjectMetadata {
  final String id;
  final String name;
  final String description;
  final int createdAt;
  final int updatedAt;
  final String version;
  final int size;

  ProjectMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.size,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'version': version,
      'size': size,
    };
  }

  factory ProjectMetadata.fromJson(Map<String, dynamic> json) {
    return ProjectMetadata(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      version: json['version'] as String,
      size: json['size'] as int,
    );
  }
}

// .sprout file format
class SproutFile {
  final String version;
  final String projectId;
  final String projectName;
  final int createdAt;
  final int exportedAt;
  final String data;
  final bool encrypted;

  SproutFile({
    required this.version,
    required this.projectId,
    required this.projectName,
    required this.createdAt,
    required this.exportedAt,
    required this.data,
    required this.encrypted,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'projectId': projectId,
      'projectName': projectName,
      'createdAt': createdAt,
      'exportedAt': exportedAt,
      'data': data,
      'encrypted': encrypted,
    };
  }

  factory SproutFile.fromJson(Map<String, dynamic> json) {
    return SproutFile(
      version: json['version'] as String,
      projectId: json['projectId'] as String,
      projectName: json['projectName'] as String,
      createdAt: json['createdAt'] as int,
      exportedAt: json['exportedAt'] as int,
      data: json['data'] as String,
      encrypted: json['encrypted'] as bool,
    );
  }
}

// Exceptions
class ProjectException implements Exception {
  final String message;

  ProjectException(this.message);
}

class ValidationException implements Exception {
  final String message;

  ValidationException(this.message);
}

class SecurityException implements Exception {
  final String message;

  SecurityException(this.message);
}