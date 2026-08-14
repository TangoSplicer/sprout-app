import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/screens/language_tools_screen.dart';
import 'package:sprout_app/services/sprout_code_assistant.dart';
import 'package:sprout_app/services/sprout_language_catalog.dart';
import 'package:sprout_app/services/sprout_preview_document.dart';

void main() {
  test(
      'local language patterns use complete advanced controls without generation',
      () {
    expect(SproutLanguageCatalog.patterns, hasLength(greaterThanOrEqualTo(5)));

    for (final pattern in SproutLanguageCatalog.patterns) {
      final source = pattern.source.replaceAll('{{appName}}', 'Pattern Test');
      final preview = SproutPreviewDocument.parse(source);
      expect(preview.hasVisibleContent, isTrue, reason: pattern.name);
      expect(
        preview.currentScreen.elements.whereType<SproutPreviewSection>(),
        isNotEmpty,
        reason: pattern.name,
      );
    }

    final journal = SproutPreviewDocument.parse(
      SproutLanguageCatalog.patterns
          .firstWhere((pattern) => pattern.name == 'Reflection journal')
          .source
          .replaceAll('{{appName}}', 'Journal'),
    );
    expect(
      journal.currentScreen.elements.whereType<SproutPreviewTextArea>(),
      isNotEmpty,
    );
    expect(
      journal.currentScreen.elements.whereType<SproutPreviewChoice>(),
      isNotEmpty,
    );

    final goals = SproutPreviewDocument.parse(
      SproutLanguageCatalog.patterns
          .firstWhere((pattern) => pattern.name == 'Goal tracker')
          .source
          .replaceAll('{{appName}}', 'Goals'),
    );
    expect(
      goals.currentScreen.elements.whereType<SproutPreviewProgress>(),
      isNotEmpty,
    );
  });

  test('local review reports concrete issues and applies a selected amendment',
      () {
    const assistant = SproutCodeAssistant();
    const legacy = '''app "Legacy" {
  start = "Home"
}

screen Home {
  state draft: ""
  ui {
    input "Write a note" binding: draft
  }
}''';

    final findings = assistant.review(legacy);
    final inputFinding = findings.firstWhere(
      (finding) => finding.amendment == SproutAmendment.moderniseInput,
    );
    expect(inputFinding.title, 'Older input syntax found');

    final modern = assistant.apply(legacy, SproutAmendment.moderniseInput);
    expect(modern, contains('input "Write a note" -> draft'));
    final richer = assistant.apply(modern, SproutAmendment.addSection);
    expect(richer, contains('section "Make this screen yours"'));

    final withSnippet = assistant.insertSnippet(
      richer,
      SproutLanguageCatalog.snippets
          .firstWhere((snippet) => snippet.title == 'Reflection'),
    );
    expect(withSnippet, contains('textarea "Write a short reflection"'));

    const recordSource = '''app "Records" { start = "Entries" }
screen Entries {
  state transactions: []
  ui {
    records transactions [kind, label, amount]
  }
}''';
    final recordFinding = assistant.review(recordSource).firstWhere(
          (finding) =>
              finding.amendment == SproutAmendment.enhanceRecordManager,
        );
    expect(recordFinding.title, 'Record history can be easier to manage');
    final enhanced =
        assistant.apply(recordSource, SproutAmendment.enhanceRecordManager);
    expect(enhanced, contains('state recordSearch: ""'));
    expect(
      enhanced,
      contains(
        'records transactions [kind, label, amount] search recordSearch editable',
      ),
    );
  });

  testWidgets('review tools expose local findings and reviewed-source action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: LanguageToolsScreen(
          projectName: 'Language Test',
          source: '''app "Test" {
  start = "Home"
}

screen Home {
  ui {
    label "Hello"
  }
}''',
        ),
      ),
    );

    expect(find.text('Language review'), findsOneWidget);
    expect(find.text('Insert a language block'), findsOneWidget);
    expect(find.text('Use reviewed source'), findsOneWidget);
    expect(find.text('Section'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
