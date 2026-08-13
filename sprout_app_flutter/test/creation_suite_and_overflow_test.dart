import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/screens/ai_screen.dart';
import 'package:sprout_app/widgets/debug_console.dart';

void main() {
  testWidgets(
      'Sprout Studio keeps guided tools and editable source visible on a phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: AIScreen(projectName: 'Studio test')),
    );

    expect(find.text('Your creation assistant is ready.'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    await tester.tap(find.text('Reminders'));
    await tester.pump();

    expect(find.text('Add useful building blocks'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -620),
    );
    await tester.pump();
    await tester.tap(find.text('Create editable starter'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(find.text('Editable source'), findsOneWidget);
    expect(find.text('Use this in my app'), findsOneWidget);
    final editors =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(editors.last.controller!.text, contains('Schedule reminder'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'terminal command help scrolls instead of overflowing in a short pane',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 160,
            child: DebugConsole(
              logs: [],
              errors: [],
              aiFeedback: 'A tailored starter was applied to the project.',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.terminal));
    await tester.pump();
    expect(find.byType(DebugConsole), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
