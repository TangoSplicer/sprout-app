import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:sprout_mobile/main.dart' as app;
import 'package:sprout_mobile/services/project_service.dart';
import 'package:sprout_mobile/services/debugger.dart';
import 'package:sprout_mobile/services/reactive_runtime.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sprout App Integration Tests', () {
    
    testWidgets('App launches and shows home screen', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.text('Sprout'), findsOneWidget);
      expect(find.text('Your Apps'), findsOneWidget);
      expect(find.text('New App'), findsOneWidget);
    });

    testWidgets('Create new project flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('New App'));
      await tester.pumpAndSettle();

      final projectName = 'TestProject${DateTime.now().millisecondsSinceEpoch}';
      
      await tester.enterText(find.byType(TextField), projectName);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('$projectName.sprout'), findsOneWidget);
    });

    testWidgets('Project service operations', (WidgetTester tester) async {
      final projectService = ProjectService();
      final testName = 'ServiceTest${DateTime.now().millisecondsSinceEpoch}';
      
      await projectService.createProject(testName);
      final projects = await projectService.loadProjectNames();
      expect(projects, contains(testName));
      
      const testCode = 'app "Test" { start = "Home" }';
      await projectService.writeFile(testName, 'main.sprout', testCode);
      final readCode = await projectService.readFile(testName, 'main.sprout');
      expect(readCode, contains('Test'));
      
      final wasm = await projectService.compileCode(testCode);
      expect(wasm, isNotEmpty);
    });

    testWidgets('Debugger functionality', (WidgetTester tester) async {
      final debugger = SproutDebugger();
      debugger.clear();
      debugger.info('Test info');
      debugger.warning('Test warning');
      debugger.error('Test error');
      
      expect(debugger.logs, hasLength(3));
      expect(debugger.errors, hasLength(1));
    });

    testWidgets('Reactive runtime operations', (WidgetTester tester) async {
      final runtime = ReactiveRuntime();
      bool watcherTriggered = false;
      
      runtime.setValue('test_key', 'initial');
      runtime.watch('test_key', (value) {
        watcherTriggered = true;
      });
      
      runtime.setValue('test_key', 'updated');
      await Future.delayed(const Duration(milliseconds: 100));
      expect(watcherTriggered, isTrue);
      
      runtime.setValue('x', 5);
      runtime.setValue('y', 3);
      runtime.computed('sum', () {
        // Casting ensures the analyzer is happy with the math
        final x = runtime.getValue('x', 0) as int;
        final y = runtime.getValue('y', 0) as int;
        return x + y;
      }, ['x', 'y']);
      
      expect(runtime.getValue('sum', 0), equals(8));
    });

    testWidgets('Security validation', (WidgetTester tester) async {
      final projectService = ProjectService();
      const dangerousCode = 'button "Evil" { eval("malicious") }';
      
      // Now that they are imported from the service, we can use isA
      expect(
        () async => await projectService.compileCode(dangerousCode),
        throwsA(isA<SecurityException>()), 
      );
    });
  });

  group('Error Handling and Recovery', () {
    testWidgets('Handle invalid project names', (WidgetTester tester) async {
      final projectService = ProjectService();
      expect(
        () async => await projectService.createProject(''), 
        throwsA(isA<ProjectException>())
      );
    });

    testWidgets('Compiler error handling', (WidgetTester tester) async {
      final projectService = ProjectService();
      expect(
        () async => await projectService.compileCode('bad { syntax'), 
        throwsA(isA<CompileException>())
      );
    });
  });
}
