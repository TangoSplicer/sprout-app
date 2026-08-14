import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/services/ai_assistant.dart';
import 'package:sprout_app/services/project_service.dart';
import 'package:sprout_app/services/sprout_preview_document.dart';

void main() {
  test(
      'saved source is recovered into Home discovery when project metadata is missing',
      () async {
    final root = await Directory.systemTemp.createTemp('sprout_recovery_test_');
    final projects = ProjectService();
    addTearDown(() async {
      projects.resetStorageDirectoryForTesting();
      await root.delete(recursive: true);
    });
    await projects.useStorageDirectoryForTesting(root);

    final projectDirectory =
        Directory('${root.path}/sprout_projects/Quiet_Garden');
    await projectDirectory.create(recursive: true);
    await File('${projectDirectory.path}/main.sprout').writeAsString(
      'app "Quiet Garden" { start = "Home" }\n'
      'screen Home { ui { label "Welcome" } }',
    );

    expect(await projects.loadProjectNames(), contains('Quiet_Garden'));
    expect(
        await File('${projectDirectory.path}/project.json').exists(), isTrue);
  });

  test(
      'malformed metadata is repaired while preserving a readable source project',
      () async {
    final root = await Directory.systemTemp.createTemp('sprout_repair_test_');
    final projects = ProjectService();
    addTearDown(() async {
      projects.resetStorageDirectoryForTesting();
      await root.delete(recursive: true);
    });
    await projects.useStorageDirectoryForTesting(root);

    final projectDirectory =
        Directory('${root.path}/sprout_projects/Weekend_Plan');
    await projectDirectory.create(recursive: true);
    await File('${projectDirectory.path}/main.sprout').writeAsString(
      'app "Weekend Plan" { start = "Home" }\n'
      'screen Home { ui { label "Welcome" } }',
    );
    await File('${projectDirectory.path}/project.json')
        .writeAsString('{broken');

    expect(await projects.loadProjectNames(), contains('Weekend_Plan'));
    final metadata =
        await File('${projectDirectory.path}/project.json').readAsString();
    expect(metadata, contains('sanitized_name'));
  });

  test('rich preview document renders and mutates bounded tracker primitives',
      () {
    const source = '''app "Focus" {
  start = "Today"
}

screen Today {
  state sessions: 0
  state paused: false
  state notes: []
  ui {
    section "Today’s focus" "A small, real plan."
    metric "Sessions completed" -> sessions
    toggle "Pause prompts" -> paused
    divider
    input "Capture a distraction" -> draft
    button "Finish session" { increment sessions }
    button "Clear notes" { clear notes }
    list notes
  }
}''';

    final document = SproutPreviewDocument.parse(source);
    expect(document.currentScreen.elements.whereType<SproutPreviewSection>(),
        isNotEmpty);
    expect(document.currentScreen.elements.whereType<SproutPreviewMetric>(),
        isNotEmpty);
    expect(document.currentScreen.elements.whereType<SproutPreviewToggle>(),
        isNotEmpty);

    final finish = document.currentScreen.elements
        .whereType<SproutPreviewButton>()
        .firstWhere((button) => button.label == 'Finish session');
    document.activate(finish);
    expect(document.metricValue('sessions'), 1);

    document.updateToggle('paused', true);
    expect(document.toggleValue('paused'), isTrue);
  });

  test('focus and budget requests produce distinct rich executable app designs',
      () async {
    final focus = await AIAssistant().generate(
      'A focus timer for my architecture study sessions',
    );
    final budget = await AIAssistant().generate(
      'A personal budget for tracking freelance spending',
    );

    expect(focus, contains('metric "Sessions completed" -> sessions'));
    expect(focus, contains('increment focusMinutes by -5'));
    expect(budget, contains('metric "Expenses logged" -> expensesLogged'));
    expect(budget, contains('Start a fresh review'));
    expect(focus, isNot(equals(budget)));

    final focusPreview = SproutPreviewDocument.parse(focus);
    final budgetPreview = SproutPreviewDocument.parse(budget);
    expect(focusPreview.currentScreen.elements.whereType<SproutPreviewMetric>(),
        hasLength(2));
    expect(
      budgetPreview.currentScreen.elements.whereType<SproutPreviewToggle>(),
      hasLength(1),
    );
  });
}
