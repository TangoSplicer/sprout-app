import 'dart:convert';
import 'security_analyzer.dart';

enum ValidationLevel {
  strict,
  standard,
  relaxed,
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic>? sanitizedData;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    this.sanitizedData,
  });

  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      'errors': errors,
      'warnings': warnings,
      'sanitizedData': sanitizedData,
    };
  }
}

class FormValidator {
  static final FormValidator _instance = FormValidator._internal();
  factory FormValidator() => _instance;
  FormValidator._internal();

  final SecurityAnalyzer _securityAnalyzer = SecurityAnalyzer();

  /// Validate text input
  ValidationResult validateTextField({
    required String fieldName,
    required String value,
    int? minLength,
    int? maxLength,
    bool required = false,
    String? pattern,
    List<String>? allowedValues,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check required
    if (required && value.isEmpty) {
      errors.add('$fieldName is required');
    }

    // Skip further validation if empty and not required
    if (value.isEmpty && !required) {
      return ValidationResult(
        isValid: true,
        errors: errors,
        warnings: warnings,
        sanitizedData: {fieldName: value},
      );
    }

    // Check length
    if (minLength != null && value.length < minLength) {
      errors.add('$fieldName must be at least $minLength characters');
    }

    if (maxLength != null && value.length > maxLength) {
      errors.add('$fieldName must be no more than $maxLength characters');
    }

    // Check pattern
    if (pattern != null) {
      final regex = RegExp(pattern);
      if (!regex.hasMatch(value)) {
        errors.add('$fieldName format is invalid');
      }
    }

    // Check allowed values
    if (allowedValues != null && !allowedValues.contains(value)) {
      errors.add('$fieldName must be one of: ${allowedValues.join(", ")}');
    }

    // Security checks
    final securityIssues = _checkForSecurityIssues(fieldName, value);
    errors.addAll(securityIssues);

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      sanitizedData: {fieldName: _sanitizeInput(value)},
    );
  }

  /// Validate email
  ValidationResult validateEmail({
    required String fieldName,
    required String value,
    bool required = false,
  }) {
    final emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
    
    return validateTextField(
      fieldName: fieldName,
      value: value,
      required: required,
      pattern: emailPattern,
      maxLength: 255,
    );
  }

  /// Validate URL
  ValidationResult validateUrl({
    required String fieldName,
    required String value,
    bool required = false,
    bool allowHttp = false,
  }) {
    final urlPattern = allowHttp
        ? r'^https?://[\w\-.]+(:\d+)?(/[\w\-./?%&=]*)?$'
        : r'^https://[\w\-.]+(:\d+)?(/[\w\-./?%&=]*)?$';
    
    final result = validateTextField(
      fieldName: fieldName,
      value: value,
      required: required,
      pattern: urlPattern,
    );

    // Add warning if using HTTP
    if (!allowHttp && value.startsWith('http://')) {
      result.warnings.add('$fieldName uses insecure HTTP protocol');
    }

    return result;
  }

  /// Validate numeric input
  ValidationResult validateNumber({
    required String fieldName,
    required String value,
    bool required = false,
    double? minValue,
    double? maxValue,
    bool isInteger = false,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    if (required && value.isEmpty) {
      errors.add('$fieldName is required');
      return ValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    if (value.isEmpty && !required) {
      return ValidationResult(
        isValid: true,
        errors: errors,
        warnings: warnings,
        sanitizedData: {fieldName: 0},
      );
    }

    final number = double.tryParse(value);
    if (number == null) {
      errors.add('$fieldName must be a valid number');
      return ValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    if (isInteger && number != number.truncateToDouble()) {
      errors.add('$fieldName must be a whole number');
    }

    if (minValue != null && number < minValue) {
      errors.add('$fieldName must be at least $minValue');
    }

    if (maxValue != null && number > maxValue) {
      errors.add('$fieldName must be no more than $maxValue');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      sanitizedData: {fieldName: isInteger ? number.toInt() : number},
    );
  }

  /// Validate form data
  ValidationResult validateForm(
    Map<String, dynamic> formData,
    Map<String, Map<String, dynamic>> validationRules,
    {ValidationLevel level = ValidationLevel.standard}
  ) {
    final errors = <String>[];
    final warnings = <String>[];
    final sanitizedData = <String, dynamic>{};

    for (var entry in formData.entries) {
      final fieldName = entry.key;
      final value = entry.value.toString();
      final rules = validationRules[fieldName];

      if (rules == null) {
        // No validation rules, just sanitize
        sanitizedData[fieldName] = _sanitizeInput(value);
        continue;
      }

      ValidationResult result;

      final fieldType = rules['type'] as String?;
      switch (fieldType) {
        case 'email':
          result = validateEmail(
            fieldName: fieldName,
            value: value,
            required: rules['required'] ?? false,
          );
          break;
        case 'url':
          result = validateUrl(
            fieldName: fieldName,
            value: value,
            required: rules['required'] ?? false,
            allowHttp: rules['allowHttp'] ?? false,
          );
          break;
        case 'number':
          result = validateNumber(
            fieldName: fieldName,
            value: value,
            required: rules['required'] ?? false,
            minValue: rules['minValue'],
            maxValue: rules['maxValue'],
            isInteger: rules['isInteger'] ?? false,
          );
          break;
        default:
          result = validateTextField(
            fieldName: fieldName,
            value: value,
            required: rules['required'] ?? false,
            minLength: rules['minLength'],
            maxLength: rules['maxLength'],
            pattern: rules['pattern'],
            allowedValues: rules['allowedValues'] as List<String>?,
          );
      }

      if (!result.isValid) {
        errors.addAll(result.errors);
      }
      warnings.addAll(result.warnings);

      if (result.sanitizedData != null) {
        sanitizedData.addAll(result.sanitizedData!);
      }
    }

    // Additional security validation based on level
    if (level == ValidationLevel.strict) {
      final securityResult = _validateSecurity(formData);
      errors.addAll(securityResult.errors);
      warnings.addAll(securityResult.warnings);
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      sanitizedData: sanitizedData,
    );
  }

  /// Sanitize input
  String _sanitizeInput(String input) {
    // Remove potentially dangerous characters
    var sanitized = input;

    // Remove null bytes
    sanitized = sanitized.replaceAll('\x00', '');

    // Remove excessive whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Trim to reasonable length
    if (sanitized.length > 10000) {
      sanitized = sanitized.substring(0, 10000);
    }

    return sanitized;
  }

  /// Check for security issues
  List<String> _checkForSecurityIssues(String fieldName, String value) {
    final issues = <String>[];

    // Check for SQL injection patterns
    final sqlPatterns = [
      r"(\bOR\b|\bAND\b).*(=|LIKE)",
      r"('--|;|--|\|\/\*|\*\/|@@)",
      r"(UNION\s+SELECT|EXEC\s*\(|EXECUTE\s*\()",
    ];

    for (var pattern in sqlPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(value)) {
        issues.add('$fieldName contains potentially dangerous SQL patterns');
        break;
      }
    }

    // Check for XSS patterns
    final xssPatterns = [
      r'<script[^>]*>.*?</script>',
      r'on\w+\s*=\s*["\'][^"\']*["\']',
      r'javascript:',
    ];

    for (var pattern in xssPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(value)) {
        issues.add('$fieldName contains potentially dangerous script content');
        break;
      }
    }

    // Check for path traversal
    if (RegExp(r'\.\.[/\\]').hasMatch(value)) {
      issues.add('$fieldName contains potentially dangerous path traversal patterns');
    }

    return issues;
  }

  /// Validate security of form data
  ValidationResult _validateSecurity(Map<String, dynamic> formData) {
    final errors = <String>[];
    final warnings = <String>[];

    // Analyze form data as code
    for (var entry in formData.entries) {
      final value = entry.value.toString();
      final report = _securityAnalyzer.analyzeCode(value, entry.key);

      if (report.criticalIssues > 0) {
        errors.add(
          '${entry.key} contains ${report.criticalIssues} critical security issues'
        );
      }

      if (report.highIssues > 0) {
        errors.add(
          '${entry.key} contains ${report.highIssues} high-severity security issues'
        );
      }

      if (report.mediumIssues > 0) {
        warnings.add(
          '${entry.key} contains ${report.mediumIssues} medium-severity security issues'
        );
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate JSON data
  ValidationResult validateJson({
    required String fieldName,
    required String value,
    bool required = false,
    List<String>? requiredFields,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    if (required && value.isEmpty) {
      errors.add('$fieldName is required');
      return ValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    if (value.isEmpty && !required) {
      return ValidationResult(
        isValid: true,
        errors: errors,
        warnings: warnings,
      );
    }

    try {
      final jsonData = jsonDecode(value) as Map<String, dynamic>;

      // Check for required fields
      if (requiredFields != null) {
        for (var field in requiredFields) {
          if (!jsonData.containsKey(field)) {
            errors.add('$fieldName missing required field: $field');
          }
        }
      }

      return ValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
        sanitizedData: {fieldName: jsonData},
      );
    } catch (e) {
      errors.add('$fieldName contains invalid JSON');
      return ValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }
  }

  /// Sanitize HTML content
  String sanitizeHtml(String html) {
    // Basic HTML sanitization - remove script tags and dangerous attributes
    var sanitized = html;

    // Remove script tags
    sanitized = sanitized.replaceAll(
      RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true),
      ''
    );

    // Remove dangerous event handlers
    sanitized = sanitized.replaceAll(
      RegExp(r'on\w+\s*=\s*["\'][^"\']*["\']', caseSensitive: false),
      ''
    );

    // Remove javascript: protocol
    sanitized = sanitized.replaceAll(
      RegExp(r'javascript:', caseSensitive: false),
      ''
    );

    return sanitized;
  }
}