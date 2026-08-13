import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';

Widget highlightCode(String code) {
  return HighlightView(
    code,
    language: 'plaintext',
    theme: githubTheme,
    padding: const EdgeInsets.all(12),
    textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 14),
  );
}
