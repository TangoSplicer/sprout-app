import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/services/ai_assistant.dart';
import 'package:sprout_app/services/sprout_preview_document.dart';
import 'package:sprout_app/widgets/syntax_editor.dart';

void main() {
  test('AI creates a ranked Todo app that preview rendering can read',
      () async {
    final code =
        await AIAssistant().generate('Create a todo list with rankings');
    final preview = SproutPreviewDocument.parse(code);

    expect(code, contains('app "Ranked Todo"'));
    expect(preview.appName, 'Ranked Todo');
    expect(preview.labels, contains('My ranked tasks'));
    expect(preview.buttons, contains('Add task'));
    expect(preview.buttons, contains('Complete first task'));
  });

  testWidgets('syntax editor accepts a replacement document from the parent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: SyntaxEditor(
              text: 'app "First" {\n}',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: SyntaxEditor(
              text: 'app "Ranked Todo" {\n}',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final editor = tester.widget<TextField>(find.byType(TextField));
    expect(editor.controller!.text, 'app "Ranked Todo" {\n}');
  });
}
