// flutter/lib/services/persistent_state.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PersistentState {
  static final PersistentState _instance = PersistentState._internal();
  factory PersistentState() => _instance;
  PersistentState._internal();

  Future<void> save(String projectId, Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('state_$projectId', jsonEncode(state));
  }

  Future<Map<String, dynamic>> load(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('state_$projectId');
    if (saved != null) {
      return Map<String, dynamic>.from(jsonDecode(saved));
    }
    return {};
  }
}