// bindings/bridge.dart
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:library/library.dart' as rust;

final _api = rust.SproutCompiler();

Future<List<int>> compileToWasm(String source) async {
  return await _api.compile(source);
}