import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:sprout_mobile/main.dart' as app;
import 'package:sprout_mobile/services/project_service.dart';
import 'package:sprout_mobile/services/debugger.dart';
import 'package:sprout_mobile/services/reactive_runtime.dart';

void main() {
  // Use the full Flutter Binding for integration tests
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sprout App Integration Tests', () {
    
    testWidgets('App launches and shows home screen', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify the home screen loads
      expect(find.text('Sprout'), findsOneWidget);
      expect(find.text('Your Apps'), findsOneWidget);
      expect(find.text('New App'), findsOneWidget);
    });

    testWidgets('Create new project flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Tap New App button
      await tester.tap(find.text('New App'));
      await tester.pumpAndSettle();

      // Enter unique project name to avoid "file already exists" errors in CI
      final projectName = 'Test Project ${DateTime.now().millisecondsSinceEpoch}';
      
      expect(find.text('New App'), findsWidgets);
      await tester.enterText(find.byType(TextField), projectName);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Should navigate to editor
      expect(find.text('$projectName.sprout'), findsOneWidget);
    });

    testWidgets('Project service operations', (WidgetTester tester) async {
      final projectService = ProjectService();
      final testName = 'Integration Test ${DateTime.now().millisecondsSinceEpoch}';
      
      // Test project creation
      await projectService.createProject(testName);
      
      // Verify project was created
      final projects = await projectService.loadProjectNames();
      expect(projects, contains(testName));
      
      // Test file operations
      final testCode = '''
app "$testName" {
  start = "Home"
}

screen Home {
  ui {
    label "Hello Integration Test"
  }
}
''';
      
      await projectService.writeFile(testName, 'main.sprout', testCode);
      final readCode = await projectService.readFile(testName, 'main.sprout');
      expect(readCode, contains('Hello Integration Test'));
      
      // Test compilation
      final wasm = await projectService.compileCode(testCode);
      expect(wasm, isNotEmpty);
    });

    testWidgets('Debugger functionality', (WidgetTester tester) async {
      final debugger = SproutDebugger();
      
      // Test logging
      debugger.clear();
      debugger.info('Test info message');
      debugger.warning('Test warning message');
      debugger.error('Test error message');
      
      expect(debugger.logs, hasLength(3));
      expect(debugger.errors, hasLength(1));
      expect(debugger.hasErrors, isTrue);
      expect(debugger.hasWarnings, isTrue);
      
      // Test stats
      final stats = debugger.getStats();
      expect(stats['total_logs'], equals(3));
      expect(stats['total_errors'], equals(1));
    });

    testWidgets('Reactive runtime operations', (WidgetTester tester) async {
      final runtime = ReactiveRuntime();
      bool watcherTriggered = false;
      
      // Test reactive values
      runtime.setValue('test_key', 'initial_value');
      expect(runtime.getValue('test_key', 'default'), equals('initial_value'));
      
      // Test watchers
      runtime.watch('test_key', (value) {
        expect(value, equals('updated_value'));
        watcherTriggered = true;
      });
      
      runtime.setValue('test_key', 'updated_value');
      
      // Allow batch update to process (increased slightly for CI stability)
      await Future.delayed(const Duration(milliseconds: 50));
      expect(watcherTriggered, isTrue);
      
      // Test computed values
      runtime.setValue('x', 5);
      runtime.setValue('y', 3);
      runtime.computed('sum', () {
        return (runtime.getValue('x', 0) as int) + (runtime.getValue('y', 0) as int);
      }, ['x', 'y']);
      
      expect(runtime.getValue('sum', 0), equals(8));
      
      // Update dependency and verify computed value updates
      runtime.setValue('x', 10);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(runtime.getValue('sum', 0), equals(13));
    });

    testWidgets('Security validation', (WidgetTester tester) async {
      final projectService = ProjectService();
      
      // Test safe code compilation
      const safeCode = '''
app "Safe App" {
  start = "Home"
}

screen Home {
  state count = 0
  
  ui {
    column {
      label "Count: \${count}"
      button "Increment" {
        count = count + 1
      }
    }
  }
}
''';
      
      final safeWasm = await projectService.compileCode(safeCode);
      expect(safeWasm, isNotEmpty);
      
      // Test dangerous code rejection
      const dangerousCode = '''
app "Dangerous App" {
  start = "Home"
}

screen Home {
  ui {
    button "Evil" {
      eval("malicious code")
    }
  }
}
''';
      
      expect(
        () async => await projectService.compileCode(dangerousCode),
        throwsA(isA<SecurityException>()),
      );
    });

    testWidgets('Performance and memory management', (WidgetTester tester) async {
      final runtime = ReactiveRuntime();
      
      // Create many reactive values to test memory management
      for (int i = 0; i < 1000; i++) {
        runtime.setValue('test_$i', i);
      }
      
      final stats = runtime.getStats();
      expect(stats.valueCount, equals(1000));
      
      // Test cleanup
      runtime.clear();
      final clearedStats = runtime.getStats();
      expect(clearedStats.valueCount, equals(0));
    });
  });

  group('Error Handling and Recovery', () {
    testWidgets('Handle invalid project names', (WidgetTester tester) async {
      final projectService = ProjectService();
      
      // Test empty name
      expect(
        () async => await projectService.createProject(''),
        throwsA(isA<ProjectException>()),
      );
      
      // Test dangerous characters
      expect(
        () async => await projectService.createProject('../../../etc/passwd'),
        throwsA(isA<ProjectException>()),
      );
    });

    testWidgets('Handle file system errors gracefully', (WidgetTester tester) async {
      final projectService = ProjectService();
      
      // Test reading non-existent file
      expect(
        () async => await projectService.readFile('NonExistent', 'main.sprout'),
        throwsA(isA<ProjectException>()),
      );
      
      // Test invalid file names
      expect(
        () async => await projectService.writeFile('test', '../../../evil.txt', 'content'),
        throwsA(isA<ProjectException>()),
      );
    });

    testWidgets('Compiler error handling', (WidgetTester tester) async {
      final projectService = ProjectService();
      
      // Test malformed SproutScript
      const malformedCode = '''
app "Bad Syntax {
  start = Home"
  
screen {
  ui 
    label "Missing braces and quotes
}
''';
      
      expect(
        () async => await projectService.compileCode(malformedCode),
        throwsA(isA<CompileException>()),
      );
    });
  });
}

// Exception classes (Ensure these match your actual implementation)
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  @override
  String toString() => 'SecurityException: $message';
}

class ProjectException implements Exception {
  final String message;
  ProjectException([this.message = ""]);
}

class CompileException implements Exception {
  final String message;
  CompileException([this.message = ""]);
}
