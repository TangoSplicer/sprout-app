// flutter/lib/services/reactive_runtime.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:wasm3_flutter/wasm3_flutter.dart';

class ReactiveRuntime extends ChangeNotifier {
  Instance? _instance;
  Uint8List? _memory;
  Map<String, dynamic> _state = {};
  final Map<String, Function> _watchers = {};

  Uint8List? get memory => _memory;
  Map<String, dynamic> get state => _state;

  Future<bool> load(Uint8List wasmBytes, {Map<String, dynamic> initialState = const {}}) async {
    _state = Map.from(initialState);
    try {
      final engine = await Engine.create();
      final module = await Module.fromBytes(engine, wasmBytes);
      _instance = await Instance.create(module);

      final memory = await _instance!.getMemory("memory");
      _memory = memory.buffer.asUint8List();

      // Simulate state sync (in real WASM: call export to update memory)
      _simulateStateSync();

      return true;
    } catch (e) {
      print("WASM load error: $e");
      return false;
    }
  }

  void _simulateStateSync() {
    // In real system: WASM calls import to update memory
    // For now: fake it every 100ms
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_memory != null && _memory!.length >= 4) {
        final newValue = _memory!.buffer.asByteData().getUint32(0, Endian.little);
        if ((_state['count'] ?? 0) != newValue) {
          _state['count'] = newValue;
          notifyListeners();
        }
      }
      return _instance != null;
    });
  }

  void dispose() {
    _instance?.dispose();
    super.dispose();
  }
}