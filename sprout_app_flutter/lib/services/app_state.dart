// flutter/lib/services/app_state.dart
import 'package:flutter/foundation.dart';
import '../models/project.dart';
import 'project_service.dart';
import 'debugger.dart';

/// Global application state management
class AppState extends ChangeNotifier {
  // Singleton instance
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();
  
  // Services
  final ProjectService _projectService = ProjectService();
  final SproutDebugger _debugger = SproutDebugger();
  
  // State variables
  List<String> _projectNames = [];
  String? _currentProject;
  bool _isLoading = false;
  String? _lastError;
  
  // Getters
  List<String> get projectNames => _projectNames;
  String? get currentProject => _currentProject;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  SproutDebugger get debugger => _debugger;
  
  /// Initialize the app state
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _loadProjects();
    } catch (e) {
      _setError('Failed to initialize app: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Load all projects
  Future<void> _loadProjects() async {
    try {
      _projectNames = await _projectService.loadProjectNames();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load projects: $e');
    }
  }
  
  /// Create a new project
  Future<void> createProject(String name) async {
    _setLoading(true);
    try {
      await _projectService.createProject(name);
      _projectNames = await _projectService.loadProjectNames();
      _currentProject = name;
      _debugger.log('Created project: $name');
      notifyListeners();
    } catch (e) {
      _setError('Failed to create project: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Set the current project
  void setCurrentProject(String name) {
    _currentProject = name;
    notifyListeners();
  }
  
  /// Delete a project
  Future<void> deleteProject(String name) async {
    _setLoading(true);
    try {
      await _projectService.deleteProject(name);
      _projectNames = await _projectService.loadProjectNames();
      if (_currentProject == name) {
        _currentProject = null;
      }
      _debugger.log('Deleted project: $name');
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete project: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Save code to a project file
  Future<void> saveCode(String code) async {
    if (_currentProject == null) {
      _setError('No project selected');
      return;
    }
    
    try {
      await _projectService.writeFile(_currentProject!, 'main.sprout', code);
      _debugger.log('Saved code to $_currentProject');
    } catch (e) {
      _setError('Failed to save code: $e');
    }
  }
  
  /// Load code from a project file
  Future<String> loadCode() async {
    if (_currentProject == null) {
      _setError('No project selected');
      return '';
    }
    
    try {
      return await _projectService.readFile(_currentProject!, 'main.sprout');
    } catch (e) {
      _setError('Failed to load code: $e');
      return '';
    }
  }
  
  /// Compile the current project
  Future<Uint8List> compileCurrentProject() async {
    if (_currentProject == null) {
      _setError('No project selected');
      return Uint8List(0);
    }
    
    _setLoading(true);
    try {
      final code = await _projectService.readFile(_currentProject!, 'main.sprout');
      final result = await _projectService.compileCode(code);
      if (result.isEmpty) {
        _setError('Compilation failed');
      } else {
        _debugger.log('Compiled $_currentProject successfully');
      }
      return result;
    } catch (e) {
      _setError('Compilation error: $e');
      return Uint8List(0);
    } finally {
      _setLoading(false);
    }
  }
  
  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _lastError = error;
    _debugger.error(error);
    notifyListeners();
  }
  
  void clearError() {
    _lastError = null;
    notifyListeners();
  }
}