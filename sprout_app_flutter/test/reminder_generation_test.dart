import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/services/ai_assistant.dart';
import 'package:sprout_app/services/sprout_preview_document.dart';

void main() {
  test('alarm requests generate a reminder app with a schedulable effect',
      () async {
    final source = await AIAssistant().generate(
      'A medication alarm with reminders for my evening vitamins',
    );

    expect(source, contains('screen Reminders'));
    expect(source, contains('reminder reminderText at reminderTime'));
    expect(source, contains('Time in 24-hour format'));

    final document = SproutPreviewDocument.parse(source);
    document.updateInput('reminderText', 'Take evening vitamins');
    document.updateInput('reminderTime', '18:30');

    final effects = document.activate(
      document.currentScreen.elements
          .whereType<SproutPreviewButton>()
          .firstWhere((button) => button.label == 'Schedule reminder'),
    );

    expect(document.listValue('scheduled'), ['Take evening vitamins at 18:30']);
    expect(effects, hasLength(1));
    expect(
      effects.single,
      isA<SproutPreviewReminderRequest>()
          .having(
              (effect) => effect.message, 'message', 'Take evening vitamins')
          .having((effect) => effect.time, 'time', '18:30'),
    );
  });

  test('event-with-alarm and task requests use materially different plans',
      () async {
    final assistant = AIAssistant();
    final events = await assistant.generate(
      'A meeting calendar with notification reminders',
    );
    final tasks = await assistant.generate('A ranked home chores todo list');

    expect(events, contains('screen Events'));
    expect(events, contains('Add event and reminder'));
    expect(events, contains('reminder eventName at eventTime'));
    expect(tasks, contains('screen Tasks'));
    expect(tasks, contains('Complete top task'));
    expect(tasks, isNot(contains('reminder eventName at eventTime')));
  });
}
