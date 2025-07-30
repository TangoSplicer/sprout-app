// flutter/lib/services/wasm_runtime.dart
import 'dart:typed_data';
import 'package:wasm3_flutter/wasm3_flutter.dart';

class WasmRuntime {
  Instance? _instance;
  Uint8List? _memory;

  Future<bool> load(Uint8List wasmBytes) async {
    try {
      final engine = await Engine.create();
      final module = await Module.fromBytes(engine, wasmBytes);
      _instance = await Instance.create(module);

      // Get memory
      final memory = await _instance!.getMemory("memory");
      _memory = memory.buffer.asUint8List();

      return true;
    } catch (e) {
      print("WASM load error: $e");
      return false;
    }
  }

  int getState() {
    if (_memory != null && _memory!.length >= 4) {
      return _memory!.buffer.asByteData().getUint32(0, Endian.little);
    }
    return 0;
  }

  void setState(int value) {
    if (_memory != null && _memory!.length >= 4) {
      _memory!.buffer.asByteData().setUint32(0, value, Endian.little);
    }
  }

  Future<void> run() async {
    if (_instance != null) {
      try {
        await _instance!.invoke("run");
      } catch (e) {
        print("WASM run error: $e");
      }
    }
  }

  void dispose() {
    _instance?.dispose();
  }
}