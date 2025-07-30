// flutter/lib/widgets/syntax_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SyntaxEditor extends StatelessWidget {
  final String text;
  final ValueChanged<String> onChanged;

  const SyntaxEditor({super.key, required this.text, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        height: 1.5,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(16),
        filled: true,
        fillColor: Colors.grey(0.05),
      ),
      controller: TextEditingController(text: text)
        ..selection = TextSelection.collapsed(offset: text.length),
      onChanged: onChanged,
      inputFormatters: [
        _SyntaxHighlightFormatter(),
      ],
    );
  }
}

class _SyntaxHighlightFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue; // In MVP: highlight in render, not input
  }
}

// Real version: use HighlightedText or flutter_highlight