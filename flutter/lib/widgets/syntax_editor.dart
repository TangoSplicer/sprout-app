import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/monokai_sublime.dart';

class SyntaxEditor extends StatefulWidget {
  final String text;
  final Function(String) onChanged;
  final bool showLineNumbers;
  final String theme;
  final bool readOnly;

  const SyntaxEditor({
    super.key,
    required this.text,
    required this.onChanged,
    this.showLineNumbers = true,
    this.theme = 'github',
    this.readOnly = false,
  });

  @override
  State<SyntaxEditor> createState() => _SyntaxEditorState();
}

class _SyntaxEditorState extends State<SyntaxEditor> {
  late TextEditingController _controller;
  late ScrollController _scrollController;
  late ScrollController _lineNumberScrollController;
  final FocusNode _focusNode = FocusNode();
  
  int _currentLine = 1;
  int _currentColumn = 1;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _scrollController = ScrollController();
    _lineNumberScrollController = ScrollController();
    
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_syncLineNumberScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCursorPosition();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _lineNumberScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.onChanged(_controller.text);
    _updateCursorPosition();
  }

  void _syncLineNumberScroll() {
    if (_lineNumberScrollController.hasClients) {
      _lineNumberScrollController.jumpTo(_scrollController.offset);
    }
  }

  void _updateCursorPosition() {
    final text = _controller.text;
    final selection = _controller.selection;
    
    if (selection.baseOffset >= 0) {
      final beforeCursor = text.substring(0, selection.baseOffset);
      final lines = beforeCursor.split('\n');
      
      setState(() {
        _currentLine = lines.length;
        _currentColumn = lines.last.length + 1;
      });
    }
  }

  Map<String, TextStyle> _getHighlightTheme() {
    switch (widget.theme) {
      case 'monokai':
        return monokaiSublimeTheme;
      case 'github':
      default:
        return githubTheme;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineCount = _controller.text.split('\n').length;
    
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showLineNumbers) _buildLineNumbers(lineCount),
                Expanded(child: _buildEditor()),
              ],
            ),
          ),
        ),
        _buildStatusBar(),
      ],
    );
  }

  Widget _buildLineNumbers(int lineCount) {
    return Container(
      width: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        controller: _lineNumberScrollController,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
              lineCount,
              (index) => Container(
                height: 20,
                alignment: Alignment.centerRight,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _currentLine == index + 1 
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade600,
                    fontFamily: 'JetBrainsMono',
                    fontWeight: _currentLine == index + 1 
                        ? FontWeight.bold 
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          children: [
            // Syntax highlighting overlay
            HighlightView(
              _controller.text,
              language: 'javascript', // Use JavaScript highlighting for now
              theme: _getHighlightTheme(),
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14,
                height: 1.25,
              ),
            ),
            // Invisible text field for input
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(
                color: Colors.transparent,
                fontFamily: 'JetBrainsMono',
                fontSize: 14,
                height: 1.25,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: null,
              readOnly: widget.readOnly,
              onChanged: (text) => widget.onChanged(text),
              cursorColor: Theme.of(context).primaryColor,
              selectionControls: MaterialTextSelectionControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.code, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            'SproutScript',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _buildStatusItem('Ln $_currentLine, Col $_currentColumn'),
          const SizedBox(width: 16),
          _buildStatusItem('UTF-8'),
          const SizedBox(width: 16),
          _buildStatusItem(widget.theme.toUpperCase()),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: Colors.grey.shade600,
        fontFamily: 'JetBrainsMono',
      ),
    );
  }
}

// Custom syntax highlighter for SproutScript
class SproutHighlighter {
  static Map<String, TextStyle> getSproutTheme() {
    return {
      'root': const TextStyle(
        backgroundColor: Color(0xfff8f8f2),
        color: Color(0xff272822),
      ),
      'keyword': const TextStyle(
        color: Color(0xfff92672),
        fontWeight: FontWeight.bold,
      ),
      'string': const TextStyle(
        color: Color(0xffe6db74),
      ),
      'number': const TextStyle(
        color: Color(0xffae81ff),
      ),
      'comment': const TextStyle(
        color: Color(0xff75715e),
        fontStyle: FontStyle.italic,
      ),
      'function': const TextStyle(
        color: Color(0xffa6e22e),
      ),
      'variable': const TextStyle(
        color: Color(0xff66d9ef),
      ),
    };
  }

  static List<HighlightSpan> highlight(String code) {
    final spans = <HighlightSpan>[];
    final theme = getSproutTheme();
    
    // Simple regex-based highlighting for SproutScript
    final patterns = {
      r'\b(app|screen|ui|state|button|label|title|column|row|if|else)\b': 'keyword',
      r'"[^"]*"': 'string',
      r'\b\d+(\.\d+)?\b': 'number',
      r'//.*': 'comment',
      r'\b[a-zA-Z_][a-zA-Z0-9_]*\s*\(': 'function',
      r'\$\{[^}]*\}': 'variable',
    };
    
    int lastEnd = 0;
    
    for (final entry in patterns.entries) {
      final regex = RegExp(entry.key);
      final matches = regex.allMatches(code);
      
      for (final match in matches) {
        if (match.start >= lastEnd) {
          spans.add(HighlightSpan(
            start: match.start,
            end: match.end,
            style: theme[entry.value] ?? theme['root']!,
          ));
          lastEnd = match.end;
        }
      }
    }
    
    return spans;
  }
}

class HighlightSpan {
  final int start;
  final int end;
  final TextStyle style;
  
  HighlightSpan({
    required this.start,
    required this.end,
    required this.style,
  });
}

