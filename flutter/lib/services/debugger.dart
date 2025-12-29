// flutter/lib/services/debugger.dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:stack_trace/stack_trace.dart';

class SproutDebugger {
  static final SproutDebugger _instance = SproutDebugger._internal();
  factory SproutDebugger() => _instance;
  SproutDebugger._internal();

  final List<LogEntry> _logs = [];
  final List<ErrorEntry> _errors = [];

  void log(String message) {
    final entry = LogEntry(message: message, timestamp: DateTime.now());
    _logs.add(entry);
    if (kDebugMode) print("[Sprout] $message");
  }

  void error(String message, {StackTrace? stack}) {
    final entry = ErrorEntry(message: message, timestamp: DateTime.now(), stack: stack);
    _errors.add(entry);
    FlutterError.reportError(
      FlutterErrorDetails(exception: message, stack: stack ?? Trace.current().vmTrace),
    );
  }

  List<LogEntry> get logs => List.unmodifiable(_logs);
  List<ErrorEntry> get errors => List.unmodifiable(_errors);
  void clear() { _logs.clear(); _errors.clear(); }
}

class LogEntry {
  final String message;
  final DateTime timestamp;
  LogEntry({required this.message, required this.timestamp});
}

class ErrorEntry {
  final String message;
  final DateTime timestamp;
  final StackTrace? stack;
  ErrorEntry({required this.message, required this.timestamp, this.stack});
}