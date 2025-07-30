// flutter/lib/services/language_server.dart
import 'dart:typed_data';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:sprout_mobile/generated_bridge.dart';

class LanguageServerClient {
  final RustBridge _bridge = rustBridge;

  Future<List<CompletionItem>> getCompletions() async {
    try {
      final result = await _bridge.languageServerRequest('completion', '{}');
      return (result as List).map((e) => CompletionItem.fromJson(e)).toList();
    } on Exception {
      return [];
    }
  }

  Future<String?> getHover(int line, int char) async {
    try {
      final params = '{"line":$line,"character":$char}';
      final result = await _bridge.languageServerRequest('hover', params);
      return result.toString();
    } on Exception {
      return null;
    }
  }

  Future<void> notifyChange(String source) async {
    await _bridge.languageServerRequest('didChange', '{"text":"$source"}');
  }
}

class CompletionItem {
  final String label;
  final String kind;
  final String? documentation;

  CompletionItem({required this.label, required this.kind, this.documentation});

  factory CompletionItem.fromJson(Map<String, dynamic> json) {
    return CompletionItem(
      label: json['label'],
      kind: json['kind'],
      documentation: json['documentation'],
    );
  }
}