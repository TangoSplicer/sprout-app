import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

enum PermissionType {
  camera,
  microphone,
  location,
  storage,
  photos,
  notifications,
  contacts,
  calendar,
}

enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  notDetermined,
}

class PermissionRequest {
  final PermissionType type;
  final String rationale;
  final String featureDescription;
  final bool isRequired;

  PermissionRequest({
    required this.type,
    required this.rationale,
    required this.featureDescription,
    this.isRequired = false,
  });
}

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  final Map<PermissionType, PermissionStatus> _permissionStatus = {};

  /// Get current status of a permission
  Future<PermissionStatus> checkPermission(PermissionType type) async {
    Permission permission = _mapPermissionType(type);
    Permission.Status status = await permission.status;

    PermissionStatus mappedStatus = _mapPermissionStatus(status);
    _permissionStatus[type] = mappedStatus;

    return mappedStatus;
  }

  /// Request a single permission
  Future<PermissionStatus> requestPermission(PermissionType type) async {
    Permission permission = _mapPermissionType(type);
    Permission.Status status = await permission.request();

    PermissionStatus mappedStatus = _mapPermissionStatus(status);
    _permissionStatus[type] = mappedStatus;

    return mappedStatus;
  }

  /// Request multiple permissions
  Future<Map<PermissionType, PermissionStatus>> requestMultiplePermissions(
    List<PermissionType> types
  ) async {
    final Map<PermissionType, PermissionStatus> results = {};

    for (var type in types) {
      final status = await requestPermission(type);
      results[type] = status;
    }

    return results;
  }

  /// Check if all required permissions are granted
  Future<bool> checkRequiredPermissions(List<PermissionRequest> requests) async {
    for (var request in requests) {
      if (request.isRequired) {
        final status = await checkPermission(request.type);
        if (status != PermissionStatus.granted) {
          return false;
        }
      }
    }
    return true;
  }

  /// Request permissions with user-friendly flow
  Future<Map<PermissionType, PermissionStatus>> requestPermissionsWithFlow(
    List<PermissionRequest> requests
  ) async {
    final results = <PermissionType, PermissionStatus>{};

    // Check current status first
    final statusCheck = await Future.wait(
      requests.map((r) => checkPermission(r.type))
    );

    // Only request permissions that aren't already granted
    final needsRequest = <PermissionRequest>[];
    for (var i = 0; i < requests.length; i++) {
      final request = requests[i];
      final status = statusCheck[i];

      results[request.type] = status;

      if (status != PermissionStatus.granted) {
        needsRequest.add(request);
      }
    }

    // Request needed permissions
    for (var request in needsRequest) {
      final status = await requestPermission(request.type);
      results[request.type] = status;
    }

    return results;
  }

  /// Open app settings for user to manually grant permissions
  Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  /// Check if permission should show rationale
  Future<bool> shouldShowRationale(PermissionType type) async {
    Permission permission = _mapPermissionType(type);
    return await permission.shouldShowRequestRationale;
  }

  /// Get permission description for UI
  String getPermissionDescription(PermissionType type) {
    switch (type) {
      case PermissionType.camera:
        return 'Camera access is needed to take photos and videos.';
      case PermissionType.microphone:
        return 'Microphone access is needed for audio recording.';
      case PermissionType.location:
        return 'Location access is needed to provide location-based features.';
      case PermissionType.storage:
        return 'Storage access is needed to save and load files.';
      case PermissionType.photos:
        return 'Photo library access is needed to select photos.';
      case PermissionType.notifications:
        return 'Notification access is needed to send you alerts and updates.';
      case PermissionType.contacts:
        return 'Contacts access is needed to interact with your contacts.';
      case PermissionType.calendar:
        return 'Calendar access is needed to manage events.';
    }
  }

  /// Analyze which permissions are needed based on app features
  List<PermissionType> analyzeRequiredPermissions(String sourceCode) {
    final neededPermissions = <PermissionType>[];

    // Camera detection
    if (sourceCode.contains('camera') || 
        sourceCode.contains('takePicture') ||
        sourceCode.contains('startVideoRecording')) {
      neededPermissions.add(PermissionType.camera);
    }

    // Microphone detection
    if (sourceCode.contains('microphone') || 
        sourceCode.contains('audio') ||
        sourceCode.contains('recorder')) {
      neededPermissions.add(PermissionType.microphone);
    }

    // Location detection
    if (sourceCode.contains('location') || 
        sourceCode.contains('geolocation') ||
        sourceCode.contains('GPS')) {
      neededPermissions.add(PermissionType.location);
    }

    // Storage detection
    if (sourceCode.contains('file') || 
        sourceCode.contains('storage') ||
        sourceCode.contains('save') ||
        sourceCode.contains('load')) {
      neededPermissions.add(PermissionType.storage);
    }

    // Photos detection
    if (sourceCode.contains('photo') || 
        sourceCode.contains('image') ||
        sourceCode.contains('gallery')) {
      neededPermissions.add(PermissionType.photos);
    }

    // Notifications detection
    if (sourceCode.contains('notification') || 
        sourceCode.contains('alert') ||
        sourceCode.contains('push')) {
      neededPermissions.add(PermissionType.notifications);
    }

    // Contacts detection
    if (sourceCode.contains('contact') || 
        sourceCode.contains('address')) {
      neededPermissions.add(PermissionType.contacts);
    }

    // Calendar detection
    if (sourceCode.contains('calendar') || 
        sourceCode.contains('event') ||
        sourceCode.contains('schedule')) {
      neededPermissions.add(PermissionType.calendar);
    }

    return neededPermissions;
  }

  /// Validate permission usage in code
  Map<String, dynamic> validatePermissionUsage({
    required List<PermissionType> requestedPermissions,
    required String sourceCode,
  }) {
    final neededPermissions = analyzeRequiredPermissions(sourceCode);
    final requested = requestedPermissions.toSet();
    final needed = neededPermissions.toSet();

    final missingPermissions = needed.difference(requested);
    final unnecessaryPermissions = requested.difference(needed);

    return {
      'isValid': missingPermissions.isEmpty,
      'requestedPermissions': requested.map((p) => p.name).toList(),
      'neededPermissions': needed.map((p) => p.name).toList(),
      'missingPermissions': missingPermissions.map((p) => p.name).toList(),
      'unnecessaryPermissions': unnecessaryPermissions.map((p) => p.name).toList(),
      'warnings': [
        if (missingPermissions.isNotEmpty)
          'Missing permissions: ${missingPermissions.map((p) => p.name).join(", ")}',
        if (unnecessaryPermissions.isNotEmpty)
          'Unnecessary permissions requested: ${unnecessaryPermissions.map((p) => p.name).join(", ")}',
      ],
    };
  }

  /// Get cached permission status
  PermissionStatus? getCachedStatus(PermissionType type) {
    return _permissionStatus[type];
  }

  /// Clear cached permission status
  void clearCache() {
    _permissionStatus.clear();
  }

  /// Map PermissionType to Permission
  Permission _mapPermissionType(PermissionType type) {
    switch (type) {
      case PermissionType.camera:
        return Permission.camera;
      case PermissionType.microphone:
        return Permission.microphone;
      case PermissionType.location:
        return Permission.location;
      case PermissionType.storage:
        return Permission.storage;
      case PermissionType.photos:
        return Permission.photos;
      case PermissionType.notifications:
        return Permission.notifications;
      case PermissionType.contacts:
        return Permission.contacts;
      case PermissionType.calendar:
        return Permission.calendar;
    }
  }

  /// Map Permission.Status to PermissionStatus
  PermissionStatus _mapPermissionStatus(Permission.Status status) {
    switch (status) {
      case Permission.Status.granted:
        return PermissionStatus.granted;
      case Permission.Status.denied:
        return PermissionStatus.denied;
      case PermissionStatus.permanentlyDenied:
        return PermissionStatus.permanentlyDenied;
      case PermissionStatus.restricted:
        return PermissionStatus.restricted;
      case PermissionStatus.limited:
        return PermissionStatus.granted;
      case PermissionStatus.provisional:
        return PermissionStatus.granted;
    }
  }
}