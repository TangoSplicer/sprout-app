import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/services/project_service.dart';
import 'package:sprout_app/services/sprout_app_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const source = '''app "Shared app" {
  start = "Home"
}

screen Home {
  state note: ""
  ui {
    section "Shared app" "A portable local Sprout app."
    input "Note" -> note
    label "{note}"
  }
}''';

  late Directory root;
  late ProjectService projects;
  late SproutAppPackageService packages;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sprout_package_test_');
    projects = ProjectService();
    await projects.useStorageDirectoryForTesting(root);
    packages = SproutAppPackageService(
      projects: projects,
      temporaryDirectoryProvider: () async => root,
    );
  });

  tearDown(() async {
    projects.resetStorageDirectoryForTesting();
    await root.delete(recursive: true);
  });

  test('exports a versioned complete app package and imports a safe named copy',
      () async {
    await projects.createProject('Travel log');
    await projects.writeFile('Travel log', 'main.sprout', source);
    await projects.writeAppState('Travel log', {
      'note': 'Book the train',
      'visits': [
        {'city': 'York', 'days': 2}
      ],
    });

    final export = await packages.exportProject(
      'Travel log',
      includeAppState: true,
    );
    expect(await export.file.exists(), isTrue);
    expect(export.file.path, endsWith(SproutAppPackageService.fileExtension));
    expect(export.manifest.includesAppState, isTrue);

    final inspected = packages.inspectFile(export.file);
    expect(inspected.manifest.projectName, 'Travel log');
    expect(inspected.source, source);
    expect(inspected.appState['note'], 'Book the train');

    final imported = await packages.importFile(export.file);
    expect(imported.projectName, 'Travel log 2');
    expect(imported.includedAppState, isTrue);
    expect(
        await projects.readFile(imported.projectName, 'main.sprout'), source);
    expect((await projects.readAppState(imported.projectName))['note'],
        'Book the train');
  });

  test('rejects packages whose source integrity does not match the manifest',
      () {
    const expectedSource = 'app "Expected" { start = "Home" }';
    const alteredSource = 'app "Altered" { start = "Home" }';
    final manifest = SproutPackageManifest(
      packageId: 'package-integrity-test',
      projectName: 'Validated app',
      createdAt: DateTime.utc(2026, 1, 1),
      includesAppState: false,
      sourceSha256: sha256.convert(utf8.encode(expectedSource)).toString(),
      stateSha256: null,
    );
    final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
    final alteredSourceBytes = utf8.encode(alteredSource);
    final archive = Archive()
      ..addFile(
          ArchiveFile('manifest.json', manifestBytes.length, manifestBytes))
      ..addFile(ArchiveFile(
          'main.sprout', alteredSourceBytes.length, alteredSourceBytes));
    final bytes = GZipEncoder().encode(TarEncoder().encode(archive))!;

    expect(
      () => packages.inspectBytes(bytes),
      throwsA(isA<SproutPackageException>()),
    );
  });

  test('rejects a hash-valid package whose source is not a Sprout app', () {
    final bytes = packages.buildPackageBytes(
      projectName: 'Not an app',
      source: 'This is ordinary text, not a Sprout document.',
    );

    expect(
      () => packages.inspectBytes(bytes),
      throwsA(isA<SproutPackageException>()),
    );
  });

  test(
      'exports source without private app data when state sharing is not selected',
      () async {
    await projects.createProject('Private notes');
    await projects.writeFile('Private notes', 'main.sprout', source);
    await projects.writeAppState('Private notes', {'note': 'Do not share me'});

    final export = await packages.exportProject('Private notes');
    final preview = packages.inspectFile(export.file);
    expect(preview.manifest.includesAppState, isFalse);
    expect(preview.appState, isEmpty);
  });
}
