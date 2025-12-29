// flutter/lib/widgets/debug_console.dart
import 'package:flutter/material.dart';

class DebugConsole extends StatelessWidget {
  final List<String> logs;
  final List<String> errors;
  final String? aiFeedback;

  const DebugConsole({super.key, 
    required this.logs, 
    required this.errors, 
    this.aiFeedback
  });

  @override
  Widget build(BuildContext context) {
    final allLines = [
      ...errors.map((e) => '❌ $e'),
      ...logs.map((l) => '✅ $l'),
      if (aiFeedback != null) '🤖 $aiFeedback'
    ];

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: allLines.isEmpty
        ? const Center(child: Text('No logs yet'))
        : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: allLines.length,
            itemBuilder: (ctx, i) => Text(allLines[i], style: const TextStyle(fontSize: 12)),
          ),
    );
  }
}