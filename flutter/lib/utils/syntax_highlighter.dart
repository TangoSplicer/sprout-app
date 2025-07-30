// flutter/lib/utils/syntax_highlighter.dart
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';

String highlightCode(String code) {
  return HighlightView(
    code,
    language: 'sprout',
    theme: githubTheme,
    padding: EdgeInsets.all(12),
    textStyle: TextStyle(fontFamily: 'monospace', fontSize: 14),
  ).toString();
}