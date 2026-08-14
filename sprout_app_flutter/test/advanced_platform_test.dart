import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/services/project_service.dart';
import 'package:sprout_app/services/sprout_language_catalog.dart';
import 'package:sprout_app/services/sprout_preview_document.dart';

void main() {
  String budgetSource() => SproutLanguageCatalog.patterns
      .firstWhere((pattern) => pattern.name == 'Month-on-month budget')
      .source
      .replaceAll('{{appName}}', 'Household budget');

  SproutPreviewButton button(SproutPreviewDocument document, String label) =>
      document.currentScreen.elements
          .whereType<SproutPreviewButton>()
          .firstWhere((element) => element.label == label);

  test(
      'month-on-month budget adds a labelled record and updates the right month',
      () {
    final document = SproutPreviewDocument.parse(budgetSource());
    expect(document.screenName, 'Dashboard');
    expect(
      document.currentScreen.elements.whereType<SproutPreviewAggregate>(),
      hasLength(2),
    );

    document.activate(button(document, 'Add an entry'));
    expect(document.screenName, 'Entry');
    document.updateInput('label', 'Music subscription');
    document.updateInput('amount', '12.50');
    document.activate(button(document, 'Save entry'));

    expect(document.screenName, 'Dashboard');
    expect(document.recordListValue('transactions'), hasLength(1));
    expect(document.recordListValue('transactions').single['label'],
        'Music subscription');
    expect(
        document.aggregateValue(
          'transactions',
          'amount',
          const ['Income · January'],
          const ['Outgoings · January', 'Debt · January', 'Savings · January'],
        ),
        12.5);

    document.activate(button(document, 'View every entry'));
    expect(document.screenName, 'Entries');
    expect(
      document.currentScreen.elements.whereType<SproutPreviewRecordList>(),
      hasLength(1),
    );
  });

  test('budget snapshots restore record data and calculated totals', () {
    final original = SproutPreviewDocument.parse(budgetSource());
    original.activate(button(original, 'Add an entry'));
    original.updateInput('label', 'Salary');
    original.updateInput('amount', '2200');
    original.activate(button(original, 'Save entry'));
    final snapshot = original.exportState();

    final restored = SproutPreviewDocument.parse(budgetSource());
    restored.restoreState(snapshot);
    expect(restored.recordListValue('transactions'), hasLength(1));
    expect(
        restored.aggregateValue(
          'transactions',
          'amount',
          const ['Income · January'],
          const ['Outgoings · January', 'Debt · January', 'Savings · January'],
        ),
        2200);
  });

  test('project service preserves a JSON-safe app-state snapshot', () async {
    final root = await Directory.systemTemp.createTemp('sprout_state_test_');
    final service = ProjectService();
    await service.useStorageDirectoryForTesting(root);
    addTearDown(() async {
      service.resetStorageDirectoryForTesting();
      await root.delete(recursive: true);
    });

    await service.createProject('Persistent budget');
    await service.writeAppState('Persistent budget', {
      'transactions': [
        {'kind': 'Income · January', 'label': 'Salary', 'amount': 2200.0}
      ],
      'month': 'January',
    });

    final state = await service.readAppState('Persistent budget');
    expect(state['month'], 'January');
    expect((state['transactions'] as List).single['label'], 'Salary');
  });
}
