import 'sprout_language_catalog.dart';

/// Deterministic language assistance for existing SproutScript documents.
///
/// This is intentionally not a generative model. It reports concrete source
/// health findings and applies small, previewable amendments chosen by the
/// author. That keeps the language and the user in control of the product.
class SproutCodeAssistant {
  const SproutCodeAssistant();

  List<SproutReviewFinding> review(String source) {
    final findings = <SproutReviewFinding>[];
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return const [
        SproutReviewFinding(
          severity: SproutReviewSeverity.error,
          title: 'No source yet',
          detail: 'Start with a local pattern or add an app declaration.',
        ),
      ];
    }

    if (!RegExp(r'app\s+"[^"]+"').hasMatch(source)) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.error,
        title: 'Missing app declaration',
        detail: 'Every document starts with app "Name" and a start screen.',
      ));
    }
    if (!RegExp(r'\bscreen\s+\w+\s*\{').hasMatch(source)) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.error,
        title: 'Missing screen',
        detail: 'Add at least one named screen with a ui block.',
      ));
    }
    if (RegExp(r'input\s+"[^"]+"\s+binding:').hasMatch(source)) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.warning,
        title: 'Older input syntax found',
        detail:
            'Use -> bindingName so the current compiler can bind the field.',
        amendment: SproutAmendment.moderniseInput,
      ));
    }
    if (!source.contains('section ')) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.hint,
        title: 'No visual grouping',
        detail: 'A section gives a screen a deliberate hierarchy and context.',
        amendment: SproutAmendment.addSection,
      ));
    }
    if (source.contains('list ') && !source.contains('clear ')) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.hint,
        title: 'List has no reset action',
        detail:
            'Consider adding a clear action for a focused, reversible flow.',
      ));
    }
    if (!source.contains('choice ') && !source.contains('toggle ')) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.hint,
        title: 'No user preference control',
        detail: 'A choice or toggle lets people adapt the app to their needs.',
        amendment: SproutAmendment.addChoice,
      ));
    }
    if (source.contains('number ') && !source.contains('records ')) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.hint,
        title: 'Numeric field is not stored as a record',
        detail:
            'Use a record action and records view when amounts need names, categories, and a durable history.',
      ));
    }
    if (source.contains('records ') &&
        !source.contains(' search ') &&
        !source.contains(' editable')) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.hint,
        title: 'Record history can be easier to manage',
        detail:
            'Add a local search field and edit controls so people can find, correct, and remove saved entries.',
        amendment: SproutAmendment.enhanceRecordManager,
      ));
    }
    if (source.contains('records ') && !source.contains('aggregate ')) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.hint,
        title: 'Structured records have no calculated view',
        detail:
            'An aggregate can turn a local record collection into a visible total without external code.',
      ));
    }
    if (source.contains('records ') && !source.contains('breakdown ')) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.hint,
        title: 'No category breakdown',
        detail:
            'A breakdown can make category totals visible alongside a full editable record history.',
      ));
    }
    if (RegExp(r'\bscreen\s+\w+\s*\{').allMatches(source).length > 1 &&
        !source.contains('go ') &&
        !source.contains('->')) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.hint,
        title: 'Multiple screens need a navigation path',
        detail:
            'Add an explicit button target or go action so every important screen is reachable.',
      ));
    }
    if (!source.contains('textarea ')) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.hint,
        title: 'No long-form capture',
        detail:
            'Add a reflection field when the app benefits from notes or context.',
        amendment: SproutAmendment.addReflection,
      ));
    }
    if (findings.isEmpty) {
      findings.add(const SproutReviewFinding(
        severity: SproutReviewSeverity.good,
        title: 'Healthy language structure',
        detail:
            'This app already uses clear local state and interactive controls.',
      ));
    }
    return findings;
  }

  String apply(String source, SproutAmendment amendment) {
    return switch (amendment) {
      SproutAmendment.moderniseInput => source.replaceAllMapped(
          RegExp(r'input\s+"([^"]+)"\s+binding:\s*(\w+)'),
          (match) => 'input "${match.group(1)}" -> ${match.group(2)}',
        ),
      SproutAmendment.addSection => _insertIntoFirstUi(
          source,
          'section "Make this screen yours" "A clear starting point that you can refine."',
        ),
      SproutAmendment.addChoice => _insertIntoFirstUi(
          source,
          'choice "How should this feel?" ["Simple", "Guided", "Focused"] -> experience',
        ),
      SproutAmendment.addReflection => _insertIntoFirstUi(
          source,
          'textarea "Write a short reflection" -> reflection',
        ),
      SproutAmendment.addProgress => _insertIntoFirstScreen(
          source,
          stateLines: const ['state progress: 0', 'state target: 7'],
          uiLine: 'progress "This week" progress / target',
        ),
      SproutAmendment.enhanceRecordManager => _enhanceFirstRecordList(source),
      SproutAmendment.insertSnippet => source,
    };
  }

  String insertSnippet(String source, SproutLanguageSnippet snippet) =>
      _insertIntoFirstUi(source, snippet.source);

  String _enhanceFirstRecordList(String source) {
    final match = RegExp(
      r'^(\s*)records\s+(\w+)\s+\[([^\]]+)\]\s*$',
      multiLine: true,
    ).firstMatch(source);
    if (match == null) return source;
    final enhanced = source.replaceRange(
      match.start,
      match.end,
      '${match.group(1)}records ${match.group(2)} [${match.group(3)}] search recordSearch editable',
    );
    return _insertIntoFirstScreen(
      enhanced,
      stateLines: const ['state recordSearch: ""'],
      uiLine: 'label "Use search to find and correct saved entries."',
    );
  }

  String _insertIntoFirstScreen(
    String source, {
    required List<String> stateLines,
    required String uiLine,
  }) {
    final screenMatch = RegExp(r'\bscreen\s+\w+\s*\{').firstMatch(source);
    if (screenMatch == null) return source;
    final uiMatch =
        RegExp(r'\bui\s*\{').firstMatch(source.substring(screenMatch.end));
    if (uiMatch == null) return source;
    final absoluteUiStart = screenMatch.end + uiMatch.start;
    final beforeUi = source.substring(0, absoluteUiStart);
    final afterUi = source.substring(absoluteUiStart);
    final missingState = stateLines
        .where((line) =>
            !RegExp('\\b${line.split(' ').last.split(':').first}\\b')
                .hasMatch(source))
        .join('\n  ');
    final withState =
        missingState.isEmpty ? source : '$beforeUi  $missingState\n  $afterUi';
    return _insertIntoFirstUi(withState, uiLine);
  }

  String _insertIntoFirstUi(String source, String line) {
    final uiMatch = RegExp(r'\bui\s*\{').firstMatch(source);
    if (uiMatch == null) return source;
    final insertion = uiMatch.end;
    return '${source.substring(0, insertion)}\n    $line${source.substring(insertion)}';
  }
}

enum SproutAmendment {
  moderniseInput,
  addSection,
  addChoice,
  addReflection,
  addProgress,
  enhanceRecordManager,
  insertSnippet,
}

enum SproutReviewSeverity { error, warning, hint, good }

class SproutReviewFinding {
  final SproutReviewSeverity severity;
  final String title;
  final String detail;
  final SproutAmendment? amendment;

  const SproutReviewFinding({
    required this.severity,
    required this.title,
    required this.detail,
    this.amendment,
  });
}
