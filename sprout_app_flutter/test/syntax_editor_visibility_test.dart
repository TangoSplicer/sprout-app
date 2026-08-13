import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/widgets/syntax_editor.dart';

void main() {
  testWidgets('source remains visible and editable in the syntax editor',
      (tester) async {
    const source = '''app "Weekend planner" {
  start = "Home"
}

screen Home {
  ui { label "Visible source" }
}''';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: SyntaxEditor(text: source, onChanged: (_) {}),
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final editable = tester.widget<EditableText>(find.byType(EditableText));

    expect(editable.controller.text, source);
    expect(field.style?.color, isNot(equals(Colors.transparent)));

    await tester.enterText(find.byType(TextField), '$source\n// edited');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      contains('// edited'),
    );
  });
}
