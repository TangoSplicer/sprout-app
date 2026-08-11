// Security Sandbox Service for Sprout
// Provides secure execution environment for SproutScript

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum SandboxLevel { restricted, standard, unrestricted }
enum SandboxViolationType { unsafe_function, network_access, file_access, memory_limit, timeout }

class SandboxViolation {
  final SandboxViolationType type;
  final String message;
  final String? code;
  final int? line;

  SandboxViolation({
    required this.type,
    required this.message,
    this.code,
    this.line,
  });

  @override
  String toString() {
    return 'SandboxViolation: $type - $message${line != null ? ' (line $line)' : ''}';
  }
}

class SandboxService {
  static final SandboxService _instance = SandboxService._internal();
  factory SandboxService() => _instance;
  SandboxService._internal();

  SandboxLevel _currentLevel = SandboxLevel.restricted;
  final List<SandboxViolation> _violations = [];
  final Set<String> _allowedDomains = {};
  final Set<String> _allowedFiles = {};

  // Security: Initialize sandbox
  void initialize({SandboxLevel level = SandboxLevel.restricted}) {
    _currentLevel = level;
    _violations.clear();
    _allowedDomains.clear();
    _allowedFiles.clear();

    // Security: Default allowed domains
    if (level == SandboxLevel.standard || level == SandboxLevel.unrestricted) {
      _allowedDomains.addAll(['localhost', '127.0.0.1']);
    }
  }

  // Security: Set sandbox level
  void setSandboxLevel(SandboxLevel level) {
    _currentLevel = level;
  }

  // Security: Get sandbox level
  SandboxLevel getSandboxLevel() {
    return _currentLevel;
  }

  // Security: Add allowed domain
  void addAllowedDomain(String domain) {
    // Security: Validate domain
    if (_isValidDomain(domain)) {
      _allowedDomains.add(domain.toLowerCase());
    }
  }

  // Security: Add allowed file path
  void addAllowedFile(String path) {
    // Security: Validate path
    if (_isValidPath(path)) {
      _allowedFiles.add(path);
    }
  }

  // Security: Validate code for sandbox violations
  List<SandboxViolation> validateCode(String code) {
    final violations = <SandboxViolation>[];

    // Security: Check for dangerous functions
    final dangerousPatterns = [
      'eval(',
      'exec(',
      'system(',
      'Function(',
      'setTimeout(',
      'setInterval(',
      'require(',
      'import(',
      'fetch(',
      'XMLHttpRequest',
      'WebSocket',
      'document.write',
      'innerHTML',
    ];

    for (var i = 0; i < code.length; i++) {
      for (final pattern in dangerousPatterns) {
        if (code.substring(i).startsWith(pattern)) {
          // Security: Check if allowed by sandbox level
          if (!_isFunctionAllowed(pattern)) {
            violations.add(SandboxViolation(
              type: SandboxViolationType.unsafe_function,
              message: 'Dangerous function detected: $pattern',
              code: pattern,
              line: _getLineNumber(code, i),
            ));
          }
        }
      }
    }

    // Security: Check for network access attempts
    final networkPatterns = [
      'http://',
      'https://',
      'ws://',
      'wss://',
    ];

    for (var i = 0; i < code.length; i++) {
      for (final pattern in networkPatterns) {
        if (code.substring(i).startsWith(pattern)) {
          // Security: Check if domain is allowed
          final urlStart = i + pattern.length;
          final urlEnd = code.indexOf('/', urlStart);
          if (urlEnd != -1) {
            final domain = code.substring(urlStart, urlEnd);
            if (!_allowedDomains.contains(domain.toLowerCase())) {
              violations.add(SandboxViolation(
                type: SandboxViolationType.network_access,
                message: 'Unallowed network access to: $domain',
                code: pattern + domain,
                line: _getLineNumber(code, i),
              ));
            }
          }
        }
      }
    }

    // Security: Check for file access attempts
    final filePatterns = [
      'File(',
      'Directory(',
      'FileSystem',
      'readFileSync',
      'writeFileSync',
    ];

    for (var i = 0; i < code.length; i++) {
      for (final pattern in filePatterns) {
        if (code.substring(i).startsWith(pattern)) {
          // Security: Check if file access is allowed
          if (_currentLevel == SandboxLevel.restricted) {
            violations.add(SandboxViolation(
              type: SandboxViolationType.file_access,
              message: 'File access not allowed in restricted sandbox',
              code: pattern,
              line: _getLineNumber(code, i),
            ));
          }
        }
      }
    }

    return violations;
  }

  // Security: Execute code in sandbox
  Future<Map<String, dynamic>> executeCode(
    String code, {
    Duration timeout = const Duration(seconds: 10),
    int maxMemory = 1024 * 1024, // 1MB
  }) async {
    final violations = validateCode(code);
    
    if (violations.isNotEmpty) {
      return {
        'success': false,
        'violations': violations.map((v) => v.toString()).toList(),
      };
    }

    // Security: Execute with timeout
    try {
      final result = await timeoutFuture(
        _executeCodeInternal(code),
        timeout: timeout,
      );

      return {
        'success': true,
        'result': result,
      };
    } on TimeoutException {
      _violations.add(SandboxViolation(
        type: SandboxViolationType.timeout,
        message: 'Execution timeout exceeded',
      ));
      
      return {
        'success': false,
        'error': 'Execution timeout',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Security: Internal code execution
  Future<dynamic> _executeCodeInternal(String code) async {
    // Security: This would integrate with the WASM runtime
    // For now, return a placeholder
    return {'status': 'executed'};
  }

  // Security: Check if function is allowed
  bool _isFunctionAllowed(String pattern) {
    // Security: Allow certain functions in higher sandbox levels
    final allowedFunctions = {
      SandboxLevel.restricted: <String>[],
      SandboxLevel.standard: <String>[],
      SandboxLevel.unrestricted: <String>[],
    };

    return allowedFunctions[_currentLevel]!.contains(pattern);
  }

  // Security: Validate domain
  bool _isValidDomain(String domain) {
    // Security: Basic domain validation
    final regex = RegExp(r'^[a-zA-Z0-9.-]+$');
    return regex.hasMatch(domain) && !domain.startsWith('.');
  }

  // Security: Validate path
  bool _isValidPath(String path) {
    // Security: Basic path validation
    return path.isNotEmpty && !path.contains('..');
  }

  // Security: Get line number
  int _getLineNumber(String code, int position) {
    var line = 1;
    for (var i = 0; i < position; i++) {
      if (code[i] == '\n') {
        line++;
      }
    }
    return line;
  }

  // Security: Get all violations
  List<SandboxViolation> getViolations() {
    return List.unmodifiable(_violations);
  }

  // Security: Clear violations
  void clearViolations() {
    _violations.clear();
  }

  // Security: Get sandbox statistics
  Map<String, dynamic> getStatistics() {
    return {
      'sandbox_level': _currentLevel.toString(),
      'violations_count': _violations.length,
      'allowed_domains_count': _allowedDomains.length,
      'allowed_files_count': _allowedFiles.length,
    };
  }
}

// Security: Timeout future
Future<T> timeoutFuture<T>(Future<T> future, {required Duration timeout}) async {
  return future.timeout(timeout);
}