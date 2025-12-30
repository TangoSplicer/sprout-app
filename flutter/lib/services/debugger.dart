import 'dart:collection';

class SproutDebugger {
  static final SproutDebugger _instance = SproutDebugger._internal();
  factory SproutDebugger() => _instance;
  SproutDebugger._internal();

  final Queue<LogEntry> _logs = Queue<LogEntry>();
  final Queue<ErrorEntry> _errors = Queue<ErrorEntry>();
  final int _maxEntries = 1000;

  List<LogEntry> get logs => _logs.toList();
  List<ErrorEntry> get errors => _errors.toList();
  
  bool get hasErrors => _errors.isNotEmpty;
  bool get hasWarnings => _logs.any((log) => log.level == LogLevel.warning);

  void log(String message, {LogLevel level = LogLevel.info, String? source}) {
    final entry = LogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
      source: source ?? 'sprout',
    );
    
    _logs.addLast(entry);
    
    // Keep only the most recent entries
    while (_logs.length > _maxEntries) {
      _logs.removeFirst();
    }
    
    // Also print to console in debug mode
    if (level == LogLevel.error) {
      print('ERROR [$source]: $message');
    } else if (level == LogLevel.warning) {
      print('WARN [$source]: $message');
    } else {
      print('INFO [$source]: $message');
    }
  }

  void error(String message, {StackTrace? stack, String? source}) {
    final entry = ErrorEntry(
      message: message,
      timestamp: DateTime.now(),
      stackTrace: stack,
      source: source ?? 'sprout',
    );
    
    _errors.addLast(entry);
    
    // Keep only the most recent errors
    while (_errors.length > _maxEntries) {
      _errors.removeFirst();
    }
    
    // Also add as a log entry
    log(message, level: LogLevel.error, source: source);
    
    // Print stack trace in debug mode
    if (stack != null) {
      print('Stack trace:\n$stack');
    }
  }

  void warning(String message, {String? source}) {
    log(message, level: LogLevel.warning, source: source);
  }

  void info(String message, {String? source}) {
    log(message, level: LogLevel.info, source: source);
  }

  void debug(String message, {String? source}) {
    log(message, level: LogLevel.debug, source: source);
  }

  void clear() {
    _logs.clear();
    _errors.clear();
  }

  void clearLogs() {
    _logs.clear();
  }

  void clearErrors() {
    _errors.clear();
  }

  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    
    final recentLogs = _logs.where((log) => log.timestamp.isAfter(oneMinuteAgo)).length;
    final recentErrors = _errors.where((error) => error.timestamp.isAfter(oneMinuteAgo)).length;
    
    final hourlyLogs = _logs.where((log) => log.timestamp.isAfter(oneHourAgo)).length;
    final hourlyErrors = _errors.where((error) => error.timestamp.isAfter(oneHourAgo)).length;
    
    return {
      'total_logs': _logs.length,
      'total_errors': _errors.length,
      'recent_logs_1min': recentLogs,
      'recent_errors_1min': recentErrors,
      'hourly_logs': hourlyLogs,
      'hourly_errors': hourlyErrors,
      'has_warnings': hasWarnings,
      'memory_usage_entries': _logs.length + _errors.length,
      'max_entries': _maxEntries,
    };
  }

  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  List<LogEntry> getLogsBySource(String source) {
    return _logs.where((log) => log.source == source).toList();
  }

  List<LogEntry> getRecentLogs({Duration? since}) {
    final cutoff = since != null 
        ? DateTime.now().subtract(since)
        : DateTime.now().subtract(const Duration(minutes: 5));
    
    return _logs.where((log) => log.timestamp.isAfter(cutoff)).toList();
  }

  void exportLogs() {
    final buffer = StringBuffer();
    buffer.writeln('Sprout Debug Log Export');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Total Entries: ${_logs.length + _errors.length}');
    buffer.writeln('');
    
    // Export errors first
    if (_errors.isNotEmpty) {
      buffer.writeln('=== ERRORS ===');
      for (final error in _errors) {
        buffer.writeln('${error.timestamp} [${error.source}] ERROR: ${error.message}');
        if (error.stackTrace != null) {
          buffer.writeln('Stack trace:');
          buffer.writeln(error.stackTrace.toString());
        }
        buffer.writeln('');
      }
    }
    
    // Export logs
    if (_logs.isNotEmpty) {
      buffer.writeln('=== LOGS ===');
      for (final log in _logs) {
        final levelStr = log.level.toString().split('.').last.toUpperCase();
        buffer.writeln('${log.timestamp} [${log.source}] $levelStr: ${log.message}');
      }
    }
    
    // In a real app, you would save this to a file or share it
    print('Log export:\n${buffer.toString()}');
  }

  // Performance monitoring
  void startPerformanceTimer(String operation) {
    log('Started: $operation', level: LogLevel.debug, source: 'perf');
    _performanceTimers[operation] = DateTime.now();
  }

  void endPerformanceTimer(String operation) {
    final startTime = _performanceTimers[operation];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      log('Completed: $operation (${duration.inMilliseconds}ms)', 
          level: LogLevel.debug, source: 'perf');
      _performanceTimers.remove(operation);
    } else {
      warning('Performance timer not found: $operation', source: 'perf');
    }
  }

  final Map<String, DateTime> _performanceTimers = {};
}

class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;
  final String source;

  const LogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
    required this.source,
  });

  @override
  String toString() {
    final levelStr = level.toString().split('.').last.toUpperCase();
    return '${timestamp.toIso8601String()} [$source] $levelStr: $message';
  }
}

class ErrorEntry {
  final String message;
  final DateTime timestamp;
  final StackTrace? stackTrace;
  final String source;

  const ErrorEntry({
    required this.message,
    required this.timestamp,
    this.stackTrace,
    required this.source,
  });

  @override
  String toString() {
    return '${timestamp.toIso8601String()} [$source] ERROR: $message';
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}
