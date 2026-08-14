import 'dart:async';
import 'dart:convert';
import '../generated_bridge.dart' as bridge;

class LanguageServerClient {
  static final LanguageServerClient _instance =
      LanguageServerClient._internal();
  factory LanguageServerClient() => _instance;
  LanguageServerClient._internal();

  final StreamController<List<Diagnostic>> _diagnosticsController =
      StreamController<List<Diagnostic>>.broadcast();
  final StreamController<List<CompletionItem>> _completionsController =
      StreamController<List<CompletionItem>>.broadcast();

  Timer? _debounceTimer;
  String _currentDocument = '';

  Stream<List<Diagnostic>> get diagnostics => _diagnosticsController.stream;
  Stream<List<CompletionItem>> get completions => _completionsController.stream;

  Future<void> notifyChange(String document) async {
    _currentDocument = document;

    // Debounce changes to avoid excessive processing
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _processDiagnostics();
    });
  }

  Future<void> _processDiagnostics() async {
    try {
      // Use the Rust bridge to parse and analyze the document
      final parseResult =
          bridge.getCompiler().parseSproutScript(_currentDocument);
      final diagnostics = _extractDiagnosticsFromParseResult(parseResult);

      _diagnosticsController.add(diagnostics);
    } catch (e) {
      // Handle parse errors
      final diagnostic = Diagnostic(
        range: const TextRange(0, 0),
        severity: DiagnosticSeverity.error,
        message: 'Parser error: $e',
        source: 'sprout-compiler',
      );
      _diagnosticsController.add([diagnostic]);
    }
  }

  List<Diagnostic> _extractDiagnosticsFromParseResult(String parseResult) {
    final diagnostics = <Diagnostic>[];

    try {
      final json = jsonDecode(parseResult);

      // Extract errors
      if (json is Map && json.containsKey('errors')) {
        final errors = json['errors'] as List?;
        if (errors != null) {
          for (final error in errors) {
            diagnostics.add(Diagnostic(
              range: const TextRange(0, 0),
              severity: DiagnosticSeverity.error,
              message: error.toString(),
              source: 'sprout-compiler',
            ));
          }
        }
      }

      // Extract warnings
      if (json is Map && json.containsKey('warnings')) {
        final warnings = json['warnings'] as List?;
        if (warnings != null) {
          for (final warning in warnings) {
            diagnostics.add(Diagnostic(
              range: const TextRange(0, 0),
              severity: DiagnosticSeverity.warning,
              message: warning.toString(),
              source: 'sprout-compiler',
            ));
          }
        }
      }
    } catch (e) {
      // Fallback error diagnostic
      diagnostics.add(Diagnostic(
        range: const TextRange(0, 0),
        severity: DiagnosticSeverity.error,
        message: 'Failed to parse diagnostics: $e',
        source: 'sprout-language-server',
      ));
    }

    return diagnostics;
  }

  Future<List<CompletionItem>> getCompletions(
      String document, int position) async {
    // Analyze context around cursor position
    final context = _analyzeContext(document, position);
    return _generateCompletions(context);
  }

  CompletionContext _analyzeContext(String document, int position) {
    if (position <= 0 || position >= document.length) {
      return CompletionContext.unknown;
    }

    final beforeCursor = document.substring(0, position);
    final lines = beforeCursor.split('\n');
    final currentLine = lines.last;

    // Determine context based on current line content
    if (currentLine.trim().isEmpty) {
      return CompletionContext.topLevel;
    }

    if (currentLine.contains('app ')) {
      return CompletionContext.appDeclaration;
    }

    if (currentLine.contains('screen ')) {
      return CompletionContext.screenDeclaration;
    }

    if (currentLine.contains('ui {') || beforeCursor.contains('ui {')) {
      return CompletionContext.uiBlock;
    }

    if (currentLine.contains('state ')) {
      return CompletionContext.stateDeclaration;
    }

    return CompletionContext.general;
  }

  List<CompletionItem> _generateCompletions(CompletionContext context) {
    final completions = <CompletionItem>[];

    switch (context) {
      case CompletionContext.topLevel:
        completions.addAll([
          const CompletionItem(
            label: 'app',
            kind: CompletionItemKind.keyword,
            detail: 'Application declaration',
            insertText: 'app "\${1:MyApp}" {\n  start = "\${2:Home}"\n}',
            documentation: 'Creates a new Sprout application',
          ),
          const CompletionItem(
            label: 'screen',
            kind: CompletionItemKind.keyword,
            detail: 'Screen declaration',
            insertText:
                'screen \${1:ScreenName} {\n  ui {\n    \${2:label "Hello World"}\n  }\n}',
            documentation: 'Creates a new screen in your app',
          ),
          const CompletionItem(
            label: 'state',
            kind: CompletionItemKind.keyword,
            detail: 'Screen state value',
            insertText: 'state \${1:progress}: \${2:0}',
            documentation:
                'Creates a local string, number, boolean, or list state value inside a screen.',
          ),
        ]);
        break;

      case CompletionContext.uiBlock:
        completions.addAll([
          const CompletionItem(
            label: 'section',
            kind: CompletionItemKind.function,
            detail: 'Visual grouping',
            insertText:
                'section "\${1:What matters}" "\${2:Supporting context}"',
            documentation:
                'Creates a purposeful title and supporting detail card.',
          ),
          const CompletionItem(
            label: 'input',
            kind: CompletionItemKind.function,
            detail: 'Single-line input',
            insertText: 'input "\${1:Label}" -> \${2:bindingName}',
            documentation:
                'Creates an editable single-line field bound to local state.',
          ),
          const CompletionItem(
            label: 'textarea',
            kind: CompletionItemKind.function,
            detail: 'Long-form input',
            insertText:
                'textarea "\${1:Write a reflection}" -> \${2:reflection}',
            documentation: 'Creates a multi-line editable text surface.',
          ),
          const CompletionItem(
            label: 'choice',
            kind: CompletionItemKind.function,
            detail: 'Choice chips',
            insertText:
                'choice "\${1:Priority}" ["\${2:Important}", "Useful", "Later"] -> \${3:priority}',
            documentation: 'Creates a bounded source-defined choice control.',
          ),
          const CompletionItem(
            label: 'progress',
            kind: CompletionItemKind.function,
            detail: 'Progress bar',
            insertText:
                'progress "\${1:This week}" \${2:progress} / \${3:target}',
            documentation: 'Renders numeric state as a progress indicator.',
          ),
          const CompletionItem(
            label: 'button',
            kind: CompletionItemKind.function,
            detail: 'Bounded action button',
            insertText:
                'button "\${1:Record progress}" {\n  increment \${2:progress}\n}',
            documentation:
                'Creates a button with safe, source-defined actions.',
          ),
          const CompletionItem(
            label: 'list',
            kind: CompletionItemKind.function,
            detail: 'Bound list',
            insertText: 'list \${1:items}',
            documentation: 'Renders a local list binding.',
          ),
        ]);
        break;

      case CompletionContext.stateDeclaration:
        completions.addAll([
          const CompletionItem(
            label: 'String',
            kind: CompletionItemKind.typeParameter,
            detail: 'Text data type',
            insertText: 'String = "\${1:default value}"',
            documentation: 'String data type for text',
          ),
          const CompletionItem(
            label: 'Int',
            kind: CompletionItemKind.typeParameter,
            detail: 'Integer data type',
            insertText: 'Int = \${1:0}',
            documentation: 'Integer data type for numbers',
          ),
          const CompletionItem(
            label: 'Boolean',
            kind: CompletionItemKind.typeParameter,
            detail: 'Boolean data type',
            insertText: 'Boolean = \${1:false}',
            documentation: 'Boolean data type for true/false',
          ),
          const CompletionItem(
            label: 'Float',
            kind: CompletionItemKind.typeParameter,
            detail: 'Decimal number data type',
            insertText: 'Float = \${1:0.0}',
            documentation: 'Float data type for decimal numbers',
          ),
        ]);
        break;

      case CompletionContext.general:
        // Add general completions that work in most contexts
        completions.addAll([
          const CompletionItem(
            label: 'true',
            kind: CompletionItemKind.value,
            detail: 'Boolean true value',
            insertText: 'true',
            documentation: 'Boolean true constant',
          ),
          const CompletionItem(
            label: 'false',
            kind: CompletionItemKind.value,
            detail: 'Boolean false value',
            insertText: 'false',
            documentation: 'Boolean false constant',
          ),
        ]);
        break;

      default:
        break;
    }

    return completions;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _diagnosticsController.close();
    _completionsController.close();
  }
}

enum CompletionContext {
  unknown,
  topLevel,
  appDeclaration,
  screenDeclaration,
  uiBlock,
  stateDeclaration,
  general,
}

class Diagnostic {
  final TextRange range;
  final DiagnosticSeverity severity;
  final String message;
  final String source;
  final String? code;

  const Diagnostic({
    required this.range,
    required this.severity,
    required this.message,
    required this.source,
    this.code,
  });

  @override
  String toString() => '$severity: $message';
}

enum DiagnosticSeverity {
  error,
  warning,
  information,
  hint,
}

class CompletionItem {
  final String label;
  final CompletionItemKind kind;
  final String? detail;
  final String? documentation;
  final String? insertText;
  final TextRange? range;

  const CompletionItem({
    required this.label,
    required this.kind,
    this.detail,
    this.documentation,
    this.insertText,
    this.range,
  });

  @override
  String toString() => label;
}

enum CompletionItemKind {
  text,
  method,
  function,
  constructor,
  field,
  variable,
  clazz,
  interfaze,
  module,
  property,
  unit,
  value,
  enumz,
  keyword,
  snippet,
  color,
  file,
  reference,
  folder,
  enumMember,
  constant,
  struct,
  event,
  operator,
  typeParameter,
}

class TextRange {
  final int start;
  final int end;

  const TextRange(this.start, this.end);

  int get length => end - start;

  @override
  String toString() => '[$start, $end]';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
