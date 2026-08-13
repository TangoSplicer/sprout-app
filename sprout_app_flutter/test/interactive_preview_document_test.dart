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
}
