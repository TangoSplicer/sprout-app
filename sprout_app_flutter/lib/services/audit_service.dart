import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class AuditEvent {
  final String id;
  final DateTime timestamp;
  final String eventType;
  final String? userId;
  final String? resource;
  final Map<String, dynamic>? metadata;
  final String? ipAddress;

  AuditEvent({
    required this.id,
    required this.timestamp,
    required this.eventType,
    this.userId,
    this.resource,
    this.metadata,
    this.ipAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'eventType': eventType,
      'userId': userId,
      'resource': resource,
      'metadata': metadata,
      'ipAddress': ipAddress,
    };
  }

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      eventType: json['eventType'] as String,
      userId: json['userId'] as String?,
      resource: json['resource'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      ipAddress: json['ipAddress'] as String?,
    );
  }
}

class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  final List<AuditEvent> _events = [];
  final int _maxEventsInMemory = 1000;
  bool _isInitialized = false;
  late Directory _auditDirectory;

  /// Initialize the audit service
  Future<void> initialize() async {
    if (_isInitialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    _auditDirectory = Directory('${appDir.path}/audit_logs');

    if (!await _auditDirectory.exists()) {
      await _auditDirectory.create(recursive: true);
    }

    _isInitialized = true;
  }

  /// Log a security event
  Future<void> logEvent({
    required String eventType,
    String? userId,
    String? resource,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final event = AuditEvent(
      id: _generateId(),
      timestamp: DateTime.now(),
      eventType: eventType,
      userId: userId,
      resource: resource,
      metadata: metadata,
    );

    _events.add(event);

    // Keep only recent events in memory
    if (_events.length > _maxEventsInMemory) {
      _events.removeAt(0);
    }

    // Persist to disk
    await _persistEvent(event);
  }

  /// Get audit events for a time range
  List<AuditEvent> getEventsInRange(DateTime start, DateTime end) {
    return _events.where((event) {
      return event.timestamp.isAfter(start) && 
             event.timestamp.isBefore(end);
    }).toList();
  }

  /// Get events by type
  List<AuditEvent> getEventsByType(String eventType) {
    return _events.where((event) => event.eventType == eventType).toList();
  }

  /// Get events by user
  List<AuditEvent> getEventsByUser(String userId) {
    return _events.where((event) => event.userId == userId).toList();
  }

  /// Get security-related events
  List<AuditEvent> getSecurityEvents() {
    final securityTypes = [
      'LOGIN_SUCCESS',
      'LOGIN_FAILURE',
      'LOGOUT',
      'PERMISSION_DENIED',
      'SECURITY_VIOLATION',
      'ENCRYPTION_FAILURE',
      'AUTHENTICATION_ERROR',
      'UNAUTHORIZED_ACCESS',
    ];

    return _events.where((event) => 
      securityTypes.contains(event.eventType)
    ).toList();
  }

  /// Generate audit report
  Map<String, dynamic> generateReport({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) {
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));
    final end = endDate ?? now;

    var events = getEventsInRange(start, end);

    if (userId != null) {
      events = events.where((e) => e.userId == userId).toList();
    }

    final eventTypeCounts = <String, int>{};
    for (var event in events) {
      eventTypeCounts[event.eventType] = 
          (eventTypeCounts[event.eventType] ?? 0) + 1;
    }

    return {
      'reportGenerated': now.toIso8601String(),
      'period': {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      },
      'userId': userId,
      'totalEvents': events.length,
      'eventTypeCounts': eventTypeCounts,
      'securityEvents': events.where((e) => 
        e.eventType.contains('SECURITY') || 
        e.eventType.contains('AUTH') ||
        e.eventType.contains('PERMISSION')
      ).length,
    };
  }

  /// Export audit logs to file
  Future<String> exportToFile(DateTime startDate, DateTime endDate) async {
    if (!_isInitialized) {
      await initialize();
    }

    final events = getEventsInRange(startDate, endDate);
    final report = generateReport(startDate: startDate, endDate: endDate);

    final exportData = {
      'report': report,
      'events': events.map((e) => e.toJson()).toList(),
    };

    final fileName = 'audit_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
    final file = File('${_auditDirectory.path}/$fileName');

    await file.writeAsString(jsonEncode(exportData));

    return file.path;
  }

  /// Persist event to disk
  Future<void> _persistEvent(AuditEvent event) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Create daily log file
    final dateStr = DateFormat('yyyy-MM-dd').format(event.timestamp);
    final logFile = File('${_auditDirectory.path}/audit_$dateStr.log');

    final logEntry = '${jsonEncode(event.toJson())}\n';
    await logFile.writeAsString(logEntry, mode: FileMode.append, flush: true);
  }

  /// Load events from disk
  Future<void> loadEventsFromDisk() async {
    if (!_isInitialized) {
      await initialize();
    }

    final files = await _auditDirectory.list().toList();

    for (var file in files) {
      if (file is File && file.path.endsWith('.log')) {
        final contents = await file.readAsString();
        final lines = contents.split('\n');

        for (var line in lines) {
          if (line.isNotEmpty) {
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;
              final event = AuditEvent.fromJson(json);
              _events.add(event);
            } catch (e) {
              // Skip malformed entries
            }
          }
        }
      }
    }

    // Sort by timestamp
    _events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Keep only recent events in memory
    if (_events.length > _maxEventsInMemory) {
      _events.removeRange(0, _events.length - _maxEventsInMemory);
    }
  }

  /// Clear old audit logs (older than specified days)
  Future<void> clearOldLogs({int daysToKeep = 90}) async {
    if (!_isInitialized) {
      await initialize();
    }

    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final files = await _auditDirectory.list().toList();

    for (var file in files) {
      if (file is File && file.path.endsWith('.log')) {
        final stat = await file.stat();
        if (stat.modified.isBefore(cutoffDate)) {
          await file.delete();
        }
      }
    }
  }

  /// Generate unique ID
  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return '$timestamp-$random';
  }

  /// Get recent events
  List<AuditEvent> getRecentEvents({int limit = 100}) {
    return _events.take(limit).toList();
  }

  /// Get event count
  int get eventCount => _events.length;

  /// Check for suspicious activity
  Map<String, dynamic> detectSuspiciousActivity() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final recentEvents = getEventsInRange(oneHourAgo, now);

    final loginFailures = recentEvents.where((e) => 
      e.eventType == 'LOGIN_FAILURE'
    ).length;

    final unauthorizedAccess = recentEvents.where((e) => 
      e.eventType == 'UNAUTHORIZED_ACCESS' || 
      e.eventType == 'PERMISSION_DENIED'
    ).length;

    final securityViolations = recentEvents.where((e) => 
      e.eventType == 'SECURITY_VIOLATION'
    ).length;

    final isSuspicious = loginFailures > 5 || 
                       unauthorizedAccess > 3 || 
                       securityViolations > 0;

    return {
      'isSuspicious': isSuspicious,
      'loginFailures': loginFailures,
      'unauthorizedAccess': unauthorizedAccess,
      'securityViolations': securityViolations,
      'timestamp': now.toIso8601String(),
    };
  }
}