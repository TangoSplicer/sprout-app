import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/services/ai_assistant.dart';
import 'package:sprout_app/services/sprout_preview_document.dart';

void main() {
  test('different requests receive distinct executable local starters',
      () async {
    final assistant = AIAssistant();
    final groceries = await assistant.generate(
      'A grocery shopping list for a weekend barbecue',
    );
    final notes = await assistant.generate(
      'A quick note catcher for work ideas',
    );
    final habits = await assistant.generate(
      'A daily habit check-in for stretching',
    );

    expect(groceries, isNot(equals(notes)));
    expect(notes, isNot(equals(habits)));
    expect(groceries, contains('considered shopping list'));
    expect(notes, contains('home for your ideas'));
    expect(habits, contains('repeatable routine'));

    for (final source in [groceries, notes, habits]) {
      final document = SproutPreviewDocument.parse(source);
      expect(document.hasVisibleContent, isTrue);
      expect(document.currentScreen.elements.whereType<SproutPreviewSection>(),
          isNotEmpty);
      expect(document.buttons, contains('Make this flow yours'));
    }
  });
}
