import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'project_service.dart';

/// Local-first collection synchronization primitives for Sprout Connect.
///
/// The service deliberately keeps transport separate from merge logic. A host
/// app can move the packet over QR, share intents, Wi-Fi Direct, or another
/// approved channel, then pass it to [mergeSyncPacket]. Every packet includes
/// a version, collection name, canonical checksum, and bounded JSON records.
class SproutConnectService {
  static final SproutConnectService _instance =
      SproutConnectService._internal();
  static const int _packetVersion = 1;
  static const int _maxRecords = 1000;
  static const int _maxPacketBytes = 200000;

  factory SproutConnectService() => _instance;
  SproutConnectService._internal();

  /// Normalizes a local collection and returns the number of retained records.
  ///
  /// This is useful before exporting a packet and removes duplicate JSON
  /// values without changing the order of the first occurrence.
  Future<int> syncCollection(String projectName, String collectionName) async {
    final projects = ProjectService();
    final state = await projects.readAppState(projectName);
    final rawList = state[collectionName];
    if (rawList is! List) return 0;

    final merged = _deduplicate(rawList);
    if (!_sameJsonList(rawList, merged)) {
      state[collectionName] = merged;
      await projects.writeAppState(projectName, state);
    }
    return merged.length;
  }

  /// Creates a portable, integrity-checked packet for one local collection.
  Future<String> createSyncPacket(
    String projectName,
    String collectionName,
  ) async {
    _validateCollectionName(collectionName);
    final projects = ProjectService();
    final state = await projects.readAppState(projectName);
    final values = state[collectionName];
    if (values is! List) {
      throw StateError('Collection does not exist: $collectionName');
    }

    final records = _deduplicate(values);
    final payload = <String, Object?>{
      'version': _packetVersion,
      'collection': collectionName,
      'records': records,
    };
    final packet = <String, Object?>{
      ...payload,
      'checksum': _checksum(payload),
    };
    final encoded = jsonEncode(packet);
    if (encoded.length > _maxPacketBytes) {
      throw StateError('Sync packet is too large');
    }
    return encoded;
  }

  /// Verifies and merges a packet into a local collection.
  ///
  /// Records with an explicit `id` are merged by ID. When both sides contain
  /// the same ID, the record with the newer valid `updatedAt` wins; otherwise
  /// the local value is retained. Records without IDs are deduplicated by
  /// canonical JSON value and appended in packet order.
  Future<SyncMergeResult> mergeSyncPacket(
    String projectName,
    String collectionName,
    String encodedPacket,
  ) async {
    _validateCollectionName(collectionName);
    if (encodedPacket.length > _maxPacketBytes) {
      throw const FormatException('Sync packet is too large');
    }
    final decoded = jsonDecode(encodedPacket);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != _packetVersion ||
        decoded['collection'] != collectionName ||
        decoded['records'] is! List ||
        decoded['checksum'] is! String) {
      throw const FormatException('Invalid Sprout Connect packet');
    }

    final payload = <String, Object?>{
      'version': decoded['version'],
      'collection': decoded['collection'],
      'records': decoded['records'],
    };
    if (!_constantTimeEquals(
      _checksum(payload),
      decoded['checksum'] as String,
    )) {
      throw const FormatException(
          'Sprout Connect packet failed integrity check');
    }

    final remote = _boundedRecords(decoded['records'] as List);
    final projects = ProjectService();
    final state = await projects.readAppState(projectName);
    final local = state[collectionName] is List
        ? _boundedRecords(state[collectionName] as List)
        : <Object?>[];
    final merged = _mergeRecords(local, remote);
    state[collectionName] = merged;
    await projects.writeAppState(projectName, state);

    return SyncMergeResult(
      localCount: local.length,
      remoteCount: remote.length,
      mergedCount: merged.length,
      addedCount: merged.length - local.length,
    );
  }

  List<Object?> _mergeRecords(List<Object?> local, List<Object?> remote) {
    final result = <Object?>[];
    final keyed = <String, int>{};
    final unkeyed = <String>{};

    void add(Object? value, {required bool isRemote}) {
      final key = _recordId(value);
      if (key != null) {
        final existingIndex = keyed[key];
        if (existingIndex == null) {
          keyed[key] = result.length;
          result.add(value);
        } else if (isRemote && _remoteIsNewer(value, result[existingIndex])) {
          result[existingIndex] = value;
        }
        return;
      }

      final canonical = _canonicalJson(value);
      if (unkeyed.add(canonical)) result.add(value);
    }

    for (final value in local) {
      add(value, isRemote: false);
    }
    for (final value in remote) {
      add(value, isRemote: true);
    }
    return result.take(_maxRecords).toList(growable: false);
  }

  List<Object?> _boundedRecords(List values) {
    if (values.length > _maxRecords) {
      throw const FormatException('Sync collection exceeds record limit');
    }
    return values.map(_jsonSafeValue).toList(growable: false);
  }

  List<Object?> _deduplicate(List values) {
    final output = <Object?>[];
    final seen = <String>{};
    for (final value in values.take(_maxRecords)) {
      final safe = _jsonSafeValue(value);
      if (seen.add(_canonicalJson(safe))) output.add(safe);
    }
    return output;
  }

  Object? _jsonSafeValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is List) return value.map(_jsonSafeValue).toList(growable: false);
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', _jsonSafeValue(item)));
    }
    throw const FormatException('Sync collection contains unsupported data');
  }

  String? _recordId(Object? value) {
    if (value is Map && value['id'] != null) return 'id:${value['id']}';
    return null;
  }

  bool _remoteIsNewer(Object? remote, Object? local) {
    if (remote is! Map || local is! Map) return false;
    final remoteTime = DateTime.tryParse('${remote['updatedAt'] ?? ''}');
    final localTime = DateTime.tryParse('${local['updatedAt'] ?? ''}');
    if (remoteTime == null || localTime == null) return false;
    return remoteTime.isAfter(localTime);
  }

  String _checksum(Map<String, Object?> payload) =>
      sha256.convert(utf8.encode(_canonicalJson(payload))).toString();

  String _canonicalJson(Object? value) {
    if (value is Map) {
      final entries = value.entries
          .map((entry) => MapEntry(entry.key.toString(), entry.value))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return '{${entries.map((entry) => '${jsonEncode(entry.key)}:${_canonicalJson(entry.value)}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    return jsonEncode(value);
  }

  bool _sameJsonList(List<Object?> left, List<Object?> right) =>
      _canonicalJson(left) == _canonicalJson(right);

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }

  void _validateCollectionName(String value) {
    if (!RegExp(r'^[A-Za-z_]\w{0,63}$').hasMatch(value)) {
      throw ArgumentError.value(value, 'collectionName');
    }
  }
}

class SyncMergeResult {
  final int localCount;
  final int remoteCount;
  final int mergedCount;
  final int addedCount;

  const SyncMergeResult({
    required this.localCount,
    required this.remoteCount,
    required this.mergedCount,
    required this.addedCount,
  });
}
