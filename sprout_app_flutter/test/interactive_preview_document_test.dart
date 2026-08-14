import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/services/sprout_preview_document.dart';

void main() {
  test('interactive preview persists Todo input, completion, and navigation',
      () {
    final document = SproutPreviewDocument.parse('''app "Ranked Todo" {
  start = "Todo"
}

screen Todo {
  state draft: ""
  state todos: []
  ui {
    input "Task to rank" -> draft
    list todos
    button "Add task" {
      todos.append(draft)
      draft = ""
    }
    button "Complete first task" { todos.remove_first() }
    button "Settings" -> Settings
  }
}

screen Settings {
  ui {
    label "Todo settings"
    button "Back" { go Back }
  }
}''');

    document.updateInput('draft', 'Buy milk');
    final add = document.currentScreen.elements
        .whereType<SproutPreviewButton>()
        .firstWhere((button) => button.label == 'Add task');
    document.activate(add);
    expect(document.listValue('todos'), ['Buy milk']);
    expect(document.inputValue('draft'), isEmpty);

    final settings = document.currentScreen.elements
        .whereType<SproutPreviewButton>()
        .firstWhere((button) => button.label == 'Settings');
    document.activate(settings);
    expect(document.screenName, 'Settings');

    final back = document.currentScreen.elements
        .whereType<SproutPreviewButton>()
        .firstWhere((button) => button.label == 'Back');
    document.activate(back);
    expect(document.screenName, 'Todo');

    final complete = document.currentScreen.elements
        .whereType<SproutPreviewButton>()
        .firstWhere((button) => button.label == 'Complete first task');
    document.activate(complete);
    expect(document.listValue('todos'), isEmpty);
  });

  test(
      'editable record views filter, update, delete, calculate, and restore local data',
      () {
    final document = SproutPreviewDocument.parse('''app "Expense log" {
  start = "Entries"
}

screen Entries {
  state transactions: []
  state entrySearch: ""
  state entryFilter: "All"
  ui {
    choice "Show category" ["All", "Essential", "Subscription"] -> entryFilter
    records transactions [kind, label, amount] search entrySearch filter entryFilter editable
    breakdown "By category" transactions amount ["Essential", "Subscription"]
  }
}''');
    document.restoreState({
      'transactions': [
        {'kind': 'Essential', 'label': 'Groceries', 'amount': 42.5},
        {'kind': 'Subscription', 'label': 'Music', 'amount': 12.5},
        {'kind': 'Subscription', 'label': 'Gym', 'amount': 18.0},
      ],
    });

    const fields = ['kind', 'label', 'amount'];
    document.updateInput('entrySearch', 'music');
    expect(
      document
          .filteredRecordEntries('transactions', fields,
              searchBinding: 'entrySearch')
          .single
          .record['label'],
      'Music',
    );

    document.updateInput('entrySearch', '');
    document.updateInput('entryFilter', 'Subscription');
    final subscriptions = document.filteredRecordEntries(
      'transactions',
      fields,
      searchBinding: 'entrySearch',
      filterBinding: 'entryFilter',
    );
    expect(
        subscriptions.map((entry) => entry.record['label']), ['Music', 'Gym']);

    document.updateRecord(
        'transactions', 2, {'label': 'Gym annual', 'amount': 20.0});
    expect(document.recordListValue('transactions')[2]['label'], 'Gym annual');
    expect(
      document.breakdownValues(
        'transactions',
        'amount',
        const ['Essential', 'Subscription'],
      ),
      {'Essential': 42.5, 'Subscription': 32.5},
    );

    document.deleteRecord('transactions', 0);
    expect(document.recordListValue('transactions'), hasLength(2));
    expect(
      document.breakdownValues(
          'transactions', 'amount', const ['Essential'])['Essential'],
      0,
    );

    final restored = SproutPreviewDocument.parse('''app "Expense log" {
  start = "Entries"
}
screen Entries {
  state transactions: []
  ui { records transactions [kind, label, amount] editable }
}''');
    restored.restoreState(document.exportState());
    expect(restored.recordListValue('transactions'), hasLength(2));
    expect(
        restored.recordListValue('transactions').last['label'], 'Gym annual');
  });
}
