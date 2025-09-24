// flutter/lib/utils/validators.dart
import 'package:flutter/material.dart';

/// Utility class for form validation
class Validators {
  /// Validate that a field is not empty
  static String? required(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    return null;
  }
  
  /// Validate that a field has a minimum length
  static String? minLength(String? value, int minLength) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    if (value.length < minLength) {
      return 'Must be at least $minLength characters';
    }
    return null;
  }
  
  /// Validate that a field has a maximum length
  static String? maxLength(String? value, int maxLength) {
    if (value == null || value.isEmpty) {
      return null; // Empty is allowed unless combined with required
    }
    if (value.length > maxLength) {
      return 'Must be at most $maxLength characters';
    }
    return null;
  }
  
  /// Validate that a field is a valid email address
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Empty is allowed unless combined with required
    }
    
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }
  
  /// Validate that a field is a valid URL
  static String? url(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Empty is allowed unless combined with required
    }
    
    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return 'Enter a valid URL';
      }
      return null;
    } catch (e) {
      return 'Enter a valid URL';
    }
  }
  
  /// Validate that a field is a valid number
  static String? number(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Empty is allowed unless combined with required
    }
    
    if (double.tryParse(value) == null) {
      return 'Enter a valid number';
    }
    return null;
  }
  
  /// Validate that a field is a valid integer
  static String? integer(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Empty is allowed unless combined with required
    }
    
    if (int.tryParse(value) == null) {
      return 'Enter a valid integer';
    }
    return null;
  }
  
  /// Validate that a field is a valid phone number
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Empty is allowed unless combined with required
    }
    
    // Simple phone validation - at least 10 digits
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    return null;
  }
  
  /// Validate that a field matches a pattern
  static String? pattern(String? value, String pattern, String errorMessage) {
    if (value == null || value.isEmpty) {
      return null; // Empty is allowed unless combined with required
    }
    
    final regex = RegExp(pattern);
    if (!regex.hasMatch(value)) {
      return errorMessage;
    }
    return null;
  }
  
  /// Validate that a field matches another field (e.g., password confirmation)
  static String? matches(String? value, String? otherValue, String fieldName) {
    if (value == null || value.isEmpty) {
      return null; // Empty is allowed unless combined with required
    }
    
    if (value != otherValue) {
      return 'Does not match $fieldName';
    }
    return null;
  }
  
  /// Combine multiple validators
  static String? combine(String? value, List<String? Function(String?)> validators) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) {
        return error;
      }
    }
    return null;
  }
  
  /// Validate a SproutScript identifier
  static String? sproutIdentifier(String? value) {
    if (value == null || value.isEmpty) {
      return 'Identifier is required';
    }
    
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(value)) {
      return 'Identifier must start with a letter or underscore and contain only letters, numbers, and underscores';
    }
    
    // Check for reserved keywords
    const reservedKeywords = [
      'app', 'screen', 'state', 'ui', 'column', 'row', 'stack', 
      'button', 'label', 'input', 'list', 'if', 'else', 'true', 
      'false', 'null', 'import', 'from', 'fn', 'return', 'for',
      'while', 'break', 'continue', 'and', 'or', 'not'
    ];
    
    if (reservedKeywords.contains(value)) {
      return '$value is a reserved keyword';
    }
    
    return null;
  }
  
  /// Validate a project name
  static String? projectName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Project name is required';
    }
    
    if (value.length < 3) {
      return 'Project name must be at least 3 characters';
    }
    
    if (value.length > 50) {
      return 'Project name must be at most 50 characters';
    }
    
    if (!RegExp(r'^[a-zA-Z0-9_\- ]+$').hasMatch(value)) {
      return 'Project name can only contain letters, numbers, spaces, underscores, and hyphens';
    }
    
    return null;
  }
  
  /// Validate SproutScript code
  static String? sproutCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Code is required';
    }
    
    // Check for app declaration
    if (!value.contains('app')) {
      return 'Code must contain an app declaration';
    }
    
    // Check for at least one screen
    if (!value.contains('screen')) {
      return 'Code must contain at least one screen';
    }
    
    // Check for balanced braces
    int braceCount = 0;
    for (int i = 0; i < value.length; i++) {
      if (value[i] == '{') {
        braceCount++;
      } else if (value[i] == '}') {
        braceCount--;
        if (braceCount < 0) {
          return 'Unbalanced braces: too many closing braces';
        }
      }
    }
    
    if (braceCount > 0) {
      return 'Unbalanced braces: missing closing braces';
    }
    
    return null;
  }
}

/// Extension methods for form validation
extension FormValidationExtension on BuildContext {
  /// Show a validation error snackbar
  void showValidationError(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}