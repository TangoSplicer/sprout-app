// flutter/lib/services/ui_binder.dart
import 'package:flutter/material.dart';

class UIBinder {
  final Map<String, dynamic> state;
  final Function(String) onAction;

  UIBinder({required this.state, required this.onAction});

  Widget buildFromCode(String code) {
    if (code.contains('Counter')) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Count: ${state['count']}', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => onAction('count = count + 1'),
            child: const Text('++'),
          ),
        ],
      );
    }
    if (code.contains('Todo')) {
      final todos = (state['todos'] as List?)?.cast<String>() ?? [];
      return Column(
        children: [
          for (var todo in todos)
            ListTile(
              title: Text(todo),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => onAction('todos.remove("$todo")'),
              ),
            ),
        ],
      );
    }
    return const Text('Preview not available');
  }
}