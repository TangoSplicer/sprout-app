// bridge/bridge.dart
import 'dart:typed_data';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'generated_bridge.dart';

final RustBridge rustBridge = RustBridge();

class RustBridge {
  late final _api = SproutCompiler();

  /// Compile SproutScript to WASM bytecode
  Future<Uint8List> compileToWasm(String source) async {
    try {
      return await _api.compile(source);
    } on Exception catch (e) {
      print("Bridge error: $e");
      return Uint8List(0);
    }
  }

  /// Parse source and return AST debug string
  Future<String> parseToAst(String source) async {
    try {
      return await _api.parse_dump(source);
    } on Exception catch (e) {
      return "Parse error: $e";
    }
  }

  /// Evaluate an expression in context (e.g. "count + 1")
  Future<String> evalExpr(String expr, Map<String, String> context) async {
    try {
      return await _api.eval_expr(expr, context);
    } on Exception catch (e) {
      return "0";
    }
  }
}