import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityIssue {
  final String severity; // 'low', 'medium', 'high', 'critical'
  final String title;
  final String description;
  final String? codeSnippet;
  final int? lineNumber;
  final String recommendation;

  SecurityIssue({
    required this.severity,
    required this.title,
    required this.description,
    this.codeSnippet,
    this.lineNumber,
    required this.recommendation,
  });

  Map<String, dynamic> toJson() {
    return {
      'severity': severity,
      'title': title,
      'description': description,
      'codeSnippet': codeSnippet,
      'lineNumber': lineNumber,
      'recommendation': recommendation,
    };
  }
}

class SecurityReport {
  final List<SecurityIssue> issues;
  final int codeQualityScore;
  final DateTime timestamp;
  final String analyzedFile;

  SecurityReport({
    required this.issues,
    required this.codeQualityScore,
    required this.timestamp,
    required this.analyzedFile,
  });

  int get criticalIssues => issues.where((i) => i.severity == 'critical').length;
  int get highIssues => issues.where((i) => i.severity == 'high').length;
  int get mediumIssues => issues.where((i) => i.severity == 'medium').length;
  int get lowIssues => issues.where((i) => i.severity == 'low').length;

  Map<String, dynamic> toJson() {
    return {
      'issues': issues.map((i) => i.toJson()).toList(),
      'codeQualityScore': codeQualityScore,
      'timestamp': timestamp.toIso8601String(),
      'analyzedFile': analyzedFile,
      'summary': {
        'critical': criticalIssues,
        'high': highIssues,
        'medium': mediumIssues,
        'low': lowIssues,
        'total': issues.length,
      },
    };
  }
}

class SecurityAnalyzer {
  // Patterns for detecting security vulnerabilities
  static const List<Map<String, String>> _securityPatterns = [
    {
      'pattern': r'eval\(',
      'severity': 'critical',
      'title': 'Use of eval() function',
      'description': 'eval() can execute arbitrary code and is a major security risk',
      'recommendation': 'Avoid eval() and use safer alternatives like JSON parsing or specific functions',
    },
    {
      'pattern': r'innerHTML\s*=',
      'severity': 'high',
      'title': 'Direct innerHTML assignment',
      'description': 'Setting innerHTML can lead to XSS vulnerabilities',
      'recommendation': 'Use textContent or sanitize HTML before assignment',
    },
    {
      'pattern': r'document\.write\(',
      'severity': 'high',
      'title': 'Use of document.write()',
      'description': 'document.write() can be used for XSS attacks',
      'recommendation': 'Use DOM manipulation methods instead',
    },
    {
      'pattern': r'localStorage\.setItem\(',
      'severity': 'medium',
      'title': 'Unencrypted localStorage usage',
      'description': 'Storing sensitive data in localStorage without encryption',
      'recommendation': 'Use encryption or secure storage alternatives',
    },
    {
      'pattern': r'sessionStorage\.setItem\(',
      'severity': 'medium',
      'title': 'Unencrypted sessionStorage usage',
      'description': 'Storing sensitive data in sessionStorage without encryption',
      'recommendation': 'Use encryption or secure storage alternatives',
    },
    {
      'pattern': r'password\s*=\s*["\'].*["\']',
      'severity': 'critical',
      'title': 'Hardcoded password detected',
      'description': 'Password is hardcoded in the source code',
      'recommendation': 'Use environment variables or secure credential management',
    },
    {
      'pattern': r'api[_-]?key\s*=\s*["\'].*["\']',
      'severity': 'critical',
      'title': 'Hardcoded API key detected',
      'description': 'API key is hardcoded in the source code',
      'recommendation': 'Use environment variables or secure credential management',
    },
    {
      'pattern': r'secret[_-]?key\s*=\s*["\'].*["\']',
      'severity': 'critical',
      'title': 'Hardcoded secret key detected',
      'description': 'Secret key is hardcoded in the source code',
      'recommendation': 'Use environment variables or secure credential management',
    },
    {
      'pattern': r'http://(?!(localhost|127\.0\.0\.1))',
      'severity': 'medium',
      'title': 'Insecure HTTP connection',
      'description': 'Using insecure HTTP protocol instead of HTTPS',
      'recommendation': 'Use HTTPS for all network communications',
    },
    {
      'pattern': r'fetch\(["\']http://',
      'severity': 'medium',
      'title': 'Insecure fetch request',
      'description': 'Making fetch requests over insecure HTTP',
      'recommendation': 'Use HTTPS for all fetch requests',
    },
  ];

  /// Analyze source code for security vulnerabilities
  SecurityReport analyzeCode(String sourceCode, String fileName) {
    final issues = <SecurityIssue>[];
    final lines = sourceCode.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;

      for (var pattern in _securityPatterns) {
        final regex = RegExp(pattern['pattern']!);
        final matches = regex.allMatches(line);

        for (var match in matches) {
          issues.add(SecurityIssue(
            severity: pattern['severity']!,
            title: pattern['title']!,
            description: pattern['description']!,
            codeSnippet: line.trim(),
            lineNumber: lineNumber,
            recommendation: pattern['recommendation']!,
          ));
        }
      }
    }

    // Additional custom checks
    issues.addAll(_checkForExternalResources(sourceCode));
    issues.addAll(_checkForNavigationTargets(sourceCode));
    issues.addAll(_checkForPermissionRequests(sourceCode));

    // Calculate code quality score
    final score = _calculateCodeQualityScore(issues);

    return SecurityReport(
      issues: issues,
      codeQualityScore: score,
      timestamp: DateTime.now(),
      analyzedFile: fileName,
    );
  }

  /// Check for external resource usage
  List<SecurityIssue> _checkForExternalResources(String sourceCode) {
    final issues = <SecurityIssue>[];
    
    final externalResourcePattern = RegExp(
      r'(https?://[^\s"\'<>]+)',
      caseSensitive: false,
    );

    final matches = externalResourcePattern.allMatches(sourceCode);
    final foundUrls = <String>{};

    for (var match in matches) {
      final url = match.group(1)!;
      if (!foundUrls.contains(url)) {
        foundUrls.add(url);
        
        // Check if URL uses HTTPS
        if (url.startsWith('http://') && 
            !url.contains('localhost') && 
            !url.contains('127.0.0.1')) {
          issues.add(SecurityIssue(
            severity: 'medium',
            title: 'External HTTP resource',
            description: 'Loading external resource over insecure HTTP',
            codeSnippet: url,
            recommendation: 'Use HTTPS for external resources',
          ));
        }
      }
    }

    return issues;
  }

  /// Check for navigation targets
  List<SecurityIssue> _checkForNavigationTargets(String sourceCode) {
    final issues = <SecurityIssue>[];
    
    final navPattern = RegExp(
      r'(navigateTo|navigate\.push|window\.location\.href)\s*\(\s*["\']([^"\']+)["\']',
      caseSensitive: false,
    );

    final matches = navPattern.allMatches(sourceCode);

    for (var match in matches) {
      final target = match.group(2)!;
      
      if (target.startsWith('http://') && 
          !target.contains('localhost')) {
        issues.add(SecurityIssue(
          severity: 'medium',
          title: 'Insecure navigation target',
          description: 'Navigating to external URL over HTTP',
          codeSnippet: target,
          recommendation: 'Use HTTPS for external navigation targets',
        ));
      }
    }

    return issues;
  }

  /// Check for permission requests
  List<SecurityIssue> _checkForPermissionRequests(String sourceCode) {
    final issues = <SecurityIssue>[];
    
    final permissionPattern = RegExp(
      r'requestPermission|request\(["\'].*permission',
      caseSensitive: false,
    );

    final matches = permissionPattern.allMatches(sourceCode);

    for (var match in matches) {
      issues.add(SecurityIssue(
        severity: 'low',
        title: 'Permission request detected',
        description: 'App requests runtime permissions',
        codeSnippet: match.group(0),
        recommendation: 'Ensure permissions are properly justified and handled',
      ));
    }

    return issues;
  }

  /// Calculate code quality score based on security issues
  int _calculateCodeQualityScore(List<SecurityIssue> issues) {
    var score = 100;

    for (var issue in issues) {
      switch (issue.severity) {
        case 'critical':
          score -= 25;
          break;
        case 'high':
          score -= 15;
          break;
        case 'medium':
          score -= 10;
          break;
        case 'low':
          score -= 5;
          break;
      }
    }

    return score.clamp(0, 100);
  }

  /// Generate a hash of the analyzed code for tracking changes
  String generateCodeHash(String sourceCode) {
    final bytes = utf8.encode(sourceCode);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Compare two security reports
  Map<String, dynamic> compareReports(SecurityReport oldReport, SecurityReport newReport) {
    final oldIssues = oldReport.issues.map((i) => i.title).toSet();
    final newIssues = newReport.issues.map((i) => i.title).toSet();

    final fixedIssues = oldIssues.difference(newIssues);
    final introducedIssues = newIssues.difference(oldIssues);

    return {
      'fixedIssues': fixedIssues.length,
      'introducedIssues': introducedIssues.length,
      'scoreChange': newReport.codeQualityScore - oldReport.codeQualityScore,
      'improvement': newReport.codeQualityScore > oldReport.codeQualityScore,
    };
  }
}