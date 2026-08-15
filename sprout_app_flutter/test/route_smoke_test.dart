import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/screens/ai_screen.dart';
import 'package:sprout_app/screens/learning_screen.dart';
import 'package:sprout_app/screens/onboarding_screen.dart';
import 'package:sprout_app/screens/project_template_screen.dart';

void main() {
  testWidgets('learning route explains the beginner workflow', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LearningScreen()));

    expect(find.text('Start with an idea, not code.'), findsOneWidget);
    expect(find.text('Your first five minutes'), findsOneWidget);
    expect(find.text('Choose a working starting point'), findsOneWidget);
  });

  testWidgets('template route presents compile-safe starter choices',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProjectTemplateScreen()));

    expect(find.text('Build from a local pattern'), findsOneWidget);
    expect(find.text('Goal tracker'), findsOneWidget);
    expect(find.text('Reflection journal'), findsOneWidget);
    expect(find.text('Create and edit source'), findsOneWidget);
  });

  testWidgets('onboarding begins with the intended welcome message',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Your idea is a seed.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('AI Use returns the generated ranked Todo app to its caller',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? acceptedCode;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                acceptedCode = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const AIScreen(projectName: 'Test App'),
                  ),
                );
              },
              child: const Text('Open AI'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open AI'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Todo list with rankings');
    await tester.tap(find.text('Create editable starter'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('Editable source'), findsOneWidget);
    await tester.tap(find.text('Use this in my app'));
    await tester.pumpAndSettle();

    expect(acceptedCode, startsWith('app "'));
    expect(acceptedCode, contains('Todo'));
    expect(
        acceptedCode, contains('input "Add a meaningful task" -> taskDraft'));
    expect(acceptedCode, contains('.remove_first()'));
  });
}
