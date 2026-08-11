// AI Code Generator Service for Sprout
// Generates secure SproutScript code from natural language

import 'package:enhanced_ai_assistant/enhanced_ai_assistant.dart';
import 'package:security_analyzer/security_analyzer.dart';
import 'package:form_validator/form_validator.dart';

class AICodeGenerator {
  static final AICodeGenerator _instance = AICodeGenerator._internal();
  factory AICodeGenerator() => _instance;
  AICodeGenerator._internal();

  final EnhancedAIAssistant _aiAssistant = EnhancedAIAssistant();
  final SecurityAnalyzer _securityAnalyzer = SecurityAnalyzer();
  final FormValidator _formValidator = FormValidator();

  // Security: Code templates
  final Map<String, String> _codeTemplates = {
    'basic_app': '''
app "{app_name}" {
  start = "Home"
}

screen Home {
  ui {
    label "Welcome to {app_name}"
  }
}
''',
    'counter_app': '''
app "Counter" {
  start = "Home"
}

screen Home {
  state {
    count = 0
  }
  
  ui {
    label "Count: ${count}"
    button "Increment" {
      action UpdateState {
        variable = "count"
        value = count + 1
      }
    }
  }
}
''',
    'list_app': '''
app "List App" {
  start = "Home"
}

screen Home {
  state {
    items = ["Item 1", "Item 2", "Item 3"]
  }
  
  ui {
    list {
      items = items
      bind_to = "selectedItem"
    }
  }
}
''',
  };

  // Security: Generate code from natural language
  Future<GeneratedCode> generateCode(
    String description, {
    String appTemplate = 'basic_app',
    ValidationLevel validationLevel = ValidationLevel.strict,
  }) async {
    try {
      // Security: Validate input
      _formValidator.validateText(description, minLength: 5, maxLength: 1000);

      // Security: Sanitize description
      final sanitizedDescription = _sanitizeInput(description);

      // Security: Get code template
      final template = _codeTemplates[appTemplate] ?? _codeTemplates['basic_app']!;

      // Security: Generate code using AI
      final generatedCode = await _aiAssistant.generateCode(
        sanitizedDescription,
        template: template,
      );

      // Security: Validate generated code
      final securityReport = _securityAnalyzer.analyzeCode(
        generatedCode,
        fileName: 'generated_${DateTime.now().millisecondsSinceEpoch}.sprout',
      );

      // Security: Check for security issues
      if (securityReport.criticalIssues > 0) {
        throw SecurityException(
          'Generated code contains ${securityReport.criticalIssues} critical security issues',
          securityReport,
        );
      }

      // Security: Apply code transformations
      final secureCode = _applySecurityTransformations(generatedCode);

      return GeneratedCode(
        code: secureCode,
        template: appTemplate,
        securityReport: securityReport,
        confidence: _calculateConfidence(generatedCode, sanitizedDescription),
      );
    } on SecurityException {
      rethrow;
    } catch (e) {
      throw GenerationException('Failed to generate code: $e');
    }
  }

  // Security: Generate code with specific features
  Future<GeneratedCode> generateCodeWithFeatures(
    String description,
    List<String> features, {
    String appTemplate = 'basic_app',
  }) async {
    try {
      // Security: Validate features
      for (final feature in features) {
        if (!_isValidFeature(feature)) {
          throw ValidationException('Invalid feature: $feature');
        }
      }

      // Security: Build enhanced description
      final enhancedDescription = _buildEnhancedDescription(description, features);

      return generateCode(
        enhancedDescription,
        appTemplate: appTemplate,
        validationLevel: ValidationLevel.strict,
      );
    } catch (e) {
      throw GenerationException('Failed to generate code with features: $e');
    }
  }

  // Security: Generate code from screenshot (future feature)
  Future<GeneratedCode> generateFromScreenshot(
    String screenshotPath, {
    String description = '',
  }) async {
    try {
      // Security: Validate screenshot path
      if (screenshotPath.isEmpty) {
        throw ValidationException('Screenshot path is required');
      }

      // Security: This would use image recognition
      // For now, return a basic template
      final code = _codeTemplates['basic_app'] ?? _codeTemplates['basic_app']!;

      final securityReport = _securityAnalyzer.analyzeCode(
        code,
        fileName: 'screenshot_${DateTime.now().millisecondsSinceEpoch}.sprout',
      );

      return GeneratedCode(
        code: code,
        template: 'basic_app',
        securityReport: securityReport,
        confidence: 0.7,
      );
    } catch (e) {
      throw GenerationException('Failed to generate from screenshot: $e');
    }
  }

  // Security: Get code suggestions
  Future<List<CodeSuggestion>> getCodeSuggestions(
    String currentCode,
    String context,
  ) async {
    try {
      // Security: Validate input
      _formValidator.validateText(currentCode, maxLength: 10000);
      _formValidator.validateText(context, maxLength: 500);

      // Security: Analyze current code
      final securityReport = _securityAnalyzer.analyzeCode(
        currentCode,
        fileName: 'current.sprout',
      );

      // Security: Get suggestions from AI
      final suggestions = await _aiAssistant.getSuggestions(
        currentCode,
        context: context,
      );

      // Security: Validate each suggestion
      final validatedSuggestions = <CodeSuggestion>[];
      for (final suggestion in suggestions) {
        final suggestionReport = _securityAnalyzer.analyzeCode(
          suggestion.code,
          fileName: 'suggestion.sprout',
        );

        if (suggestionReport.criticalIssues == 0) {
          validatedSuggestions.add(CodeSuggestion(
            code: suggestion.code,
            description: suggestion.description,
            confidence: suggestion.confidence,
            securityScore: suggestionReport.codeQualityScore,
          ));
        }
      }

      return validatedSuggestions;
    } catch (e) {
      throw GenerationException('Failed to get code suggestions: $e');
    }
  }

  // Security: Refactor code
  Future<GeneratedCode> refactorCode(
    String code,
    String goal, {
    ValidationLevel validationLevel = ValidationLevel.strict,
  }) async {
    try {
      // Security: Validate input
      _formValidator.validateText(code, maxLength: 10000);
      _formValidator.validateText(goal, maxLength: 500);

      // Security: Analyze current code
      final currentReport = _securityAnalyzer.analyzeCode(
        code,
        fileName: 'current.sprout',
      );

      // Security: Refactor using AI
      final refactoredCode = await _aiAssistant.refactorCode(code, goal: goal);

      // Security: Validate refactored code
      final refactoredReport = _securityAnalyzer.analyzeCode(
        refactoredCode,
        fileName: 'refactored.sprout',
      );

      // Security: Check for security issues
      if (refactoredReport.criticalIssues > 0) {
        throw SecurityException(
          'Refactored code contains ${refactoredReport.criticalIssues} critical security issues',
          refactoredReport,
        );
      }

      // Security: Apply security transformations
      final secureCode = _applySecurityTransformations(refactoredCode);

      return GeneratedCode(
        code: secureCode,
        template: 'refactored',
        securityReport: refactoredReport,
        confidence: _calculateRefactoringConfidence(currentReport, refactoredReport),
      );
    } on SecurityException {
      rethrow;
    } catch (e) {
      throw GenerationException('Failed to refactor code: $e');
    }
  }

  // Security: Apply security transformations
  String _applySecurityTransformations(String code) {
    var secureCode = code;

    // Security: Remove dangerous patterns
    secureCode = secureCode.replaceAll(RegExp(r'eval\s*\('), '/* eval removed */');
    secureCode = secureCode.replaceAll(RegExp(r'exec\s*\('), '/* exec removed */');
    secureCode = secureCode.replaceAll(RegExp(r'system\s*\('), '/* system removed */');

    // Security: Add security comments
    secureCode = '// Generated by AI - Security validated\n' + secureCode;

    return secureCode;
  }

  // Security: Sanitize input
  String _sanitizeInput(String input) {
    var sanitized = input.trim();

    // Security: Remove dangerous characters
    sanitized = sanitized.replaceAll(RegExp(r'[<>&quot;\'\\]'), '');

    // Security: Limit length
    if (sanitized.length > 1000) {
      sanitized = sanitized.substring(0, 1000);
    }

    return sanitized;
  }

  // Security: Validate feature
  bool _isValidFeature(String feature) {
    final validFeatures = [
      'authentication',
      'database',
      'api',
      'forms',
      'navigation',
      'state_management',
      'animation',
      'localization',
    ];

    return validFeatures.contains(feature.toLowerCase());
  }

  // Security: Build enhanced description
  String _buildEnhancedDescription(String description, List<String> features) {
    final featuresText = features.join(', ');
    return '$description. Include features: $featuresText';
  }

  // Security: Calculate confidence
  double _calculateConfidence(String code, String description) {
    // Security: Simple confidence calculation
    final codeLength = code.length;
    final descriptionLength = description.length;

    if (codeLength > 100 && descriptionLength > 10) {
      return 0.8;
    } else if (codeLength > 50) {
      return 0.6;
    } else {
      return 0.4;
    }
  }

  // Security: Calculate refactoring confidence
  double _calculateRefactoringConfidence(
    SecurityReport current,
    SecurityReport refactored,
  ) {
    // Security: Compare security scores
    final scoreImprovement = refactored.codeQualityScore - current.codeQualityScore;
    
    if (scoreImprovement > 10) {
      return 0.9;
    } else if (scoreImprovement > 5) {
      return 0.7;
    } else {
      return 0.5;
    }
  }
}

// Generated code result
class GeneratedCode {
  final String code;
  final String template;
  final SecurityReport securityReport;
  final double confidence;

  GeneratedCode({
    required this.code,
    required this.template,
    required this.securityReport,
    required this.confidence,
  });
}

// Code suggestion
class CodeSuggestion {
  final String code;
  final String description;
  final double confidence;
  final int securityScore;

  CodeSuggestion({
    required this.code,
    required this.description,
    required this.confidence,
    required this.securityScore,
  });
}

// Exceptions
class SecurityException implements Exception {
  final String message;
  final SecurityReport securityReport;

  SecurityException(this.message, this.securityReport);
}

class GenerationException implements Exception {
  final String message;

  GenerationException(this.message);
}

class ValidationException implements Exception {
  final String message;

  ValidationException(this.message);
}