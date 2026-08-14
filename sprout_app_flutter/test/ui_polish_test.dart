import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/screens/project_template_screen.dart';
import 'package:sprout_app/screens/settings_screen.dart';
import 'package:sprout_app/widgets/preview_container.dart';

void main() {
  testWidgets('preview frame adapts to compact and wide layouts',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PreviewContainer(child: SizedBox.expand()),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('sprout-preview-frame'))).width,
        360);

    await tester.binding.setSurfaceSize(const Size(900, 700));
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('sprout-preview-frame'))).width,
        390);
  });

  testWidgets(
      'settings communicates real local capabilities without dead switches',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('Keep Sprout calm and predictable.'), findsOneWidget);
    expect(find.text('Starter planning'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Local project storage'), 180);
    expect(find.text('Local project storage'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('template picker includes a language-first goal-tracker pattern',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ProjectTemplateScreen()));

    expect(find.text('Goal tracker'), findsOneWidget);
    expect(find.text('Create and edit source'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
