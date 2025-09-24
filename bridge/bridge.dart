// bridge/bridge.dart
import 'dart:typed_data';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'dart:async';
import 'generated_bridge.dart';

/// Custom exception for Sprout compiler errors
class SproutCompilerException implements Exception {
  final String message;
  final String? details;
  final StackTrace? stackTrace;

  SproutCompilerException(this.message, {this.details, this.stackTrace});

  @override
  String toString() {
    if (details != null) {
      return 'SproutCompilerException: $message\nDetails: $details';
    }
    return 'SproutCompilerException: $message';
  }
}

/// Result class for compilation operations
class CompilationResult<T> {
  final T? data;
  final SproutCompilerException? error;
  final bool isSuccess;

  CompilationResult.success(this.data) : error = null, isSuccess = true;
  CompilationResult.error(this.error) : data = null, isSuccess = false;

  bool get hasError => error != null;
}

final RustBridge rustBridge = RustBridge();

class RustBridge {
  late final _api = SproutCompiler();
  final _logger = SproutLogger();

  /// Compile SproutScript to WASM bytecode
  Future<CompilationResult<Uint8List>> compileToWasm(String source) async {
    try {
      _logger.info('Compiling SproutScript to WASM');
      final startTime = DateTime.now();
      
      final result = await _api.compile(source);
      
      final duration = DateTime.now().difference(startTime);
      _logger.info('Compilation completed in ${duration.inMilliseconds}ms');
      
      if (result.isEmpty) {
        return CompilationResult.error(
          SproutCompilerException('Compilation produced empty output')
        );
      }
      
      return CompilationResult.success(result);
    } on FfiException catch (e) {
      _logger.error('FFI error during compilation', e);
      return CompilationResult.error(
        SproutCompilerException('FFI error', details: e.toString(), stackTrace: e.stackTrace)
      );
    } on Exception catch (e, stack) {
      _logger.error('Unexpected error during compilation', e);
      return CompilationResult.error(
        SproutCompilerException('Compilation error', details: e.toString(), stackTrace: stack)
      );
    }
  }

  /// Parse source and return AST debug string
  Future<CompilationResult<String>> parseToAst(String source) async {
    try {
      _logger.info('Parsing SproutScript to AST');
      final result = await _api.parse_dump(source);
      
      if (result.startsWith('ParseError:')) {
        return CompilationResult.error(
          SproutCompilerException('Parse error', details: result.substring(12))
        );
      }
      
      return CompilationResult.success(result);
    } on Exception catch (e, stack) {
      _logger.error('Error parsing to AST', e);
      return CompilationResult.error(
        SproutCompilerException('Parse error', details: e.toString(), stackTrace: stack)
      );
    }
  }

  /// Evaluate an expression in context (e.g. "count + 1")
  Future<CompilationResult<String>> evalExpr(String expr, Map<String, String> context) async {
    try {
      _logger.info('Evaluating expression: $expr');
      
      // Simple expression evaluation for basic arithmetic
      if (expr.contains('+')) {
        final parts = expr.split('+').map((s) => s.trim()).toList();
        if (parts.length == 2) {
          // Try to resolve variables from context
          var left = _resolveValue(parts[0], context);
          var right = _resolveValue(parts[1], context);
          
          // Try numeric addition
          try {
            final result = double.parse(left) + double.parse(right);
            return CompilationResult.success(result.toString());
          } catch (e) {
            // Fall back to string concatenation
            return CompilationResult.success(left + right);
          }
        }
      } else if (expr.contains('-')) {
        final parts = expr.split('-').map((s) => s.trim()).toList();
        if (parts.length == 2) {
          var left = _resolveValue(parts[0], context);
          var right = _resolveValue(parts[1], context);
          
          try {
            final result = double.parse(left) - double.parse(right);
            return CompilationResult.success(result.toString());
          } catch (e) {
            return CompilationResult.error(
              SproutCompilerException('Invalid subtraction', details: '$left - $right')
            );
          }
        }
      } else if (expr.contains('*')) {
        final parts = expr.split('*').map((s) => s.trim()).toList();
        if (parts.length == 2) {
          var left = _resolveValue(parts[0], context);
          var right = _resolveValue(parts[1], context);
          
          try {
            final result = double.parse(left) * double.parse(right);
            return CompilationResult.success(result.toString());
          } catch (e) {
            return CompilationResult.error(
              SproutCompilerException('Invalid multiplication', details: '$left * $right')
            );
          }
        }
      } else if (expr.contains('/')) {
        final parts = expr.split('/').map((s) => s.trim()).toList();
        if (parts.length == 2) {
          var left = _resolveValue(parts[0], context);
          var right = _resolveValue(parts[1], context);
          
          try {
            final rightNum = double.parse(right);
            if (rightNum == 0) {
              return CompilationResult.error(
                SproutCompilerException('Division by zero')
              );
            }
            
            final result = double.parse(left) / rightNum;
            return CompilationResult.success(result.toString());
          } catch (e) {
            return CompilationResult.error(
              SproutCompilerException('Invalid division', details: '$left / $right')
            );
          }
        }
      }
      
      // If it's a simple variable, look it up in context
      return CompilationResult.success(_resolveValue(expr, context));
    } on Exception catch (e, stack) {
      _logger.error('Expression evaluation error', e);
      return CompilationResult.error(
        SproutCompilerException('Evaluation error', details: e.toString(), stackTrace: stack)
      );
    }
  }
  
  /// Helper to resolve a value from context or return as-is
  String _resolveValue(String key, Map<String, String> context) {
    key = key.trim();
    if (context.containsKey(key)) {
      return context[key]!;
    }
    return key; // Return as-is if not found in context
  }
}

/// Simple logger for the Rust bridge
class SproutLogger {
  void info(String message) {
    print('📘 [Sprout] INFO: $message');
  }
  
  void error(String message, [dynamic error]) {
    print('❌ [Sprout] ERROR: $message');
    if (error != null) {
      print('  Details: $error');
    }
  }
  
  void warning(String message) {
    print('⚠️ [Sprout] WARNING: $message');
  }
  
  void debug(String message) {
    print('🔍 [Sprout] DEBUG: $message');
  }
}