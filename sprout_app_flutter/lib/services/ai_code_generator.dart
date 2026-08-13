import 'enhanced_ai_assistant.dart';
import 'form_validator.dart';
import 'security_analyzer.dart';

class AICodeGenerator {
  static final AICodeGenerator _instance = AICodeGenerator._internal();

  factory AICodeGenerator() => _instance;

  AICodeGenerator._internal();

  final EnhancedAIAssistant _aiAssistant = EnhancedAIAssistant();
  final SecurityAnalyzer _securityAnalyzer = SecurityAnalyzer();
  final FormValidator _formValidator = FormValidator();

  final Map<String, String> _codeTemplates = {
    'basic_app': '''app "{app_name}" {
  start = "Home"
}

screen Home {
  ui {
    label "Welcome to {app_name}"
  }
}
''',
    'counter_app': '''app "Counter" {
  start = "Home"
}

screen Home {
  state count = 0

  ui {
    column {
      label "Count: \${count}"
      button "Increment" {
        count = count + 1
      }
    }
  }
}
''',
  };

  Future<GeneratedCode> generateCode(
    String description, {
    String appTemplate = 'basic_app',
    ValidationLevel validationLevel = ValidationLevel.strict,
  }) async {
    final validation = _formValidator.validateTextField(
      fieldName: 'description',
      value: description,
      required: true,
      minLength: 5,
      maxLength: 1000,
    );
    if (!validation.isValid) {
      throw ValidationException(validation.errors.join('; '));
    }

    final generated = await _aiAssistant.generate(_sanitizeInput(description));
    final code = generated.isSuccess
        ? generated.code
        : _templateFor(appTemplate, description);
    final report = _securityAnalyzer.analyzeCode(
      code,
      'generated_${DateTime.now().millisecondsSinceEpoch}.sprout',
    );
    _rejectCriticalIssues(report);

    return GeneratedCode(
      code: _applySecurityTransformations(code),
      template: appTemplate,
      securityReport: report,
      confidence: _calculateConfidence(code, description),
    );
  }

  Future<GeneratedCode> generateCodeWithFeatures(
    String description,
    List<String> features, {
    String appTemplate = 'basic_app',
  }) async {
    for (final feature in features) {
      if (!_isValidFeature(feature)) {
        throw ValidationException('Invalid feature: $feature');
      }
    }

    final featureDescription = features.isEmpty
        ? description
        : '$description. Include: ${features.join(', ')}.';
    return generateCode(featureDescription, appTemplate: appTemplate);
  }

  Future<GeneratedCode> generateFromScreenshot(
    String screenshotPath, {
    String description = '',
  }) async {
    if (screenshotPath.trim().isEmpty) {
      throw const ValidationException('Screenshot path is required');
    }

    final code = _templateFor(
        'basic_app', description.isEmpty ? 'Sprout App' : description);
    final report = _securityAnalyzer.analyzeCode(code, 'screenshot.sprout');
    return GeneratedCode(
      code: code,
      template: 'basic_app',
      securityReport: report,
      confidence: 0.5,
    );
  }

  Future<List<CodeSuggestion>> getCodeSuggestions(
    String currentCode,
    String context,
  ) async {
    final validation = _formValidator.validateTextField(
      fieldName: 'currentCode',
      value: currentCode,
      required: true,
      maxLength: 10000,
    );
    if (!validation.isValid) {
      throw ValidationException(validation.errors.join('; '));
    }

    final report = _securityAnalyzer.analyzeCode(currentCode, 'current.sprout');
    final safeCode = _applySecurityTransformations(currentCode);
    return [
      CodeSuggestion(
        code: safeCode,
        description: report.issues.isEmpty
            ? 'No high-risk patterns detected.'
            : 'Remove or replace the detected insecure patterns.',
        confidence: report.criticalIssues == 0 ? 0.8 : 0.4,
        securityScore: report.codeQualityScore,
      ),
    ];
  }

  Future<GeneratedCode> refactorCode(
    String code,
    String goal, {
    ValidationLevel validationLevel = ValidationLevel.strict,
  }) async {
    final validation = _formValidator.validateTextField(
      fieldName: 'code',
      value: code,
      required: true,
      maxLength: 10000,
    );
    if (!validation.isValid) {
      throw ValidationException(validation.errors.join('; '));
    }

    final secureCode = _applySecurityTransformations(code);
    final report =
        _securityAnalyzer.analyzeCode(secureCode, 'refactored.sprout');
    _rejectCriticalIssues(report);
    return GeneratedCode(
      code: secureCode,
      template: 'refactored',
      securityReport: report,
      confidence: report.codeQualityScore / 100,
    );
  }

  String _templateFor(String appTemplate, String description) {
    final appName = _sanitizeInput(description).replaceAll(' ', '_');
    return (_codeTemplates[appTemplate] ?? _codeTemplates['basic_app']!)
        .replaceAll('{app_name}', appName.isEmpty ? 'Sprout_App' : appName);
  }

  void _rejectCriticalIssues(SecurityReport report) {
    if (report.criticalIssues > 0) {
      throw SecurityException(
        'Generated code contains ${report.criticalIssues} critical security issues',
        report,
      );
    }
  }

  String _applySecurityTransformations(String code) {
    var secured = code;
    secured = secured.replaceAll(RegExp(r'eval\s*\('), '/* blocked eval */');
    secured = secured.replaceAll(RegExp(r'exec\s*\('), '/* blocked exec */');
    secured =
        secured.replaceAll(RegExp(r'system\s*\('), '/* blocked system */');
    return '// Security-validated generated code\n$secured';
  }

  String _sanitizeInput(String input) {
    final sanitized = input.replaceAll(RegExp(r'''[<>&"'\\]'''), '').trim();
    return sanitized.length > 1000 ? sanitized.substring(0, 1000) : sanitized;
  }

  bool _isValidFeature(String feature) => const {
        'authentication',
        'database',
        'api',
        'forms',
        'navigation',
        'state_management',
        'animation',
        'localization',
      }.contains(feature.toLowerCase());

  double _calculateConfidence(String code, String description) {
    if (code.length > 100 && description.length > 10) return 0.8;
    if (code.length > 50) return 0.6;
    return 0.4;
  }
}

class GeneratedCode {
  final String code;
  final String template;
  final SecurityReport securityReport;
  final double confidence;

  const GeneratedCode({
    required this.code,
    required this.template,
    required this.securityReport,
    required this.confidence,
  });
}

class CodeSuggestion {
  final String code;
  final String description;
  final double confidence;
  final int securityScore;

  const CodeSuggestion({
    required this.code,
    required this.description,
    required this.confidence,
    required this.securityScore,
  });
}

class SecurityException implements Exception {
  final String message;
  final SecurityReport securityReport;

  const SecurityException(this.message, this.securityReport);

  @override
  String toString() => 'SecurityException: $message';
}

class GenerationException implements Exception {
  final String message;

  const GenerationException(this.message);

  @override
  String toString() => 'GenerationException: $message';
}

class ValidationException implements Exception {
  final String message;

  const ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}
