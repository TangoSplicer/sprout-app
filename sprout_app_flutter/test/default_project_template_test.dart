import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/services/project_service.dart';
import 'package:sprout_app/services/sprout_preview_document.dart';

void main() {
  late Directory root;
  late ProjectService projects;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sprout_default_project_');
    projects = ProjectService();
    await projects.useStorageDirectoryForTesting(root);
  });

  tearDown(() async {
    projects.resetStorageDirectoryForTesting();
    await root.delete(recursive: true);
  });

  test('a new project starts with valid interactive current-language source',
      () async {
    await projects.createProject('Useful starter');
    final source = await projects.readFile('Useful starter', 'main.sprout');
    final preview = SproutPreviewDocument.parse(source);

    expect(preview.appName, 'Useful starter');
    expect(preview.screenName, 'Home');
    expect(preview.currentScreen.elements.whereType<SproutPreviewSection>(),
        isNotEmpty);
    expect(preview.currentScreen.elements.whereType<SproutPreviewInput>(),
        isNotEmpty);
    expect(preview.currentScreen.elements.whereType<SproutPreviewButton>(),
        isNotEmpty);
  });
}
