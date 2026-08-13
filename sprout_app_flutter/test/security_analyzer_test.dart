import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_app/services/security_analyzer.dart';

void main() {
  group('SecurityAnalyzer Tests', () {
    late SecurityAnalyzer analyzer;

    setUp(() {
      analyzer = SecurityAnalyzer();
    });

    test('Detects eval() usage', () {
      const code = '''
        function test() {
          var result = eval(userInput);
          return result;
        }
      ''';

      final report = analyzer.analyzeCode(code, 'test.js');

      expect(report.issues.length, greaterThan(0));
      expect(
        report.issues.any((issue) => issue.title.contains('eval')),
        isTrue,
      );
      expect(report.criticalIssues, greaterThan(0));
    });

    test('Detects innerHTML assignment', () {
      const code = '''
        element.innerHTML = userInput;
      ''';

      final report = analyzer.analyzeCode(code, 'test.js');

      expect(
        report.issues.any((issue) => issue.title.contains('innerHTML')),
        isTrue,
      );
      expect(report.highIssues, greaterThan(0));
    });

    test('Detects hardcoded passwords', () {
      const code = '''
        const password = "hardcoded_password_123";
      ''';

      final report = analyzer.analyzeCode(code, 'test.js');

      expect(
        report.issues
            .any((issue) => issue.title.contains('Hardcoded password')),
        isTrue,
      );
      expect(report.criticalIssues, greaterThan(0));
    });

    test('Detects hardcoded API keys', () {
      const code = '''
        const apiKey = "sk-1234567890abcdef";
      ''';

      final report = analyzer.analyzeCode(code, 'test.js');

      expect(
        report.issues.any((issue) => issue.title.contains('API key')),
        isTrue,
      );
      expect(report.criticalIssues, greaterThan(0));
    });

    test('Detects insecure HTTP connections', () {
      const code = '''
        fetch('http://example.com/data');
      ''';

      final report = analyzer.analyzeCode(code, 'test.js');

      final httpIssues = report.issues.where((issue) =>
          issue.title.contains('HTTP') && issue.severity == 'medium');

      expect(httpIssues.length, greaterThan(0));
    });

    test('Allows secure HTTPS connections', () {
      const code = '''
        fetch('https://example.com/data');
      ''';

      final report = analyzer.analyzeCode(code, 'test.js');

      final httpIssues =
          report.issues.where((issue) => issue.title.contains('HTTP'));

      expect(httpIssues.length, equals(0));
    });

    test('Detects localStorage usage', () {
      const code = '''
        localStorage.setItem('token', userToken);
      ''';

      final report = analyzer.analyzeCode(code, 'test.js');

      expect(
        report.issues.any((issue) => issue.title.contains('localStorage')),
        isTrue,
      );
      expect(report.mediumIssues, greaterThan(0));
    });

    test('Calculates code quality score correctly', () {
      const safeCode = '''
        function greet(name) {
          return "Hello, " + name;
        }
      ''';

      final safeReport = analyzer.analyzeCode(safeCode, 'safe.js');
      expect(safeReport.codeQualityScore, equals(100));

      const unsafeCode = '''
        eval(userInput);
        localStorage.setItem('key', 'value');
        document.write(content);
      ''';

      final unsafeReport = analyzer.analyzeCode(unsafeCode, 'unsafe.js');
      expect(unsafeReport.codeQualityScore, lessThan(100));
      expect(unsafeReport.codeQualityScore, greaterThan(0));
    });

    test('Detects script injection attempts', () {
      const code = '''
        const content = "<script>alert('XSS')</script>";
      ''';

      final report = analyzer.analyzeCode(code, 'test.js');

      expect(
        report.issues.any((issue) =>
            issue.title.contains('innerHTML') || issue.severity == 'high'),
        isTrue,
      );
    });

    test('Generates consistent code hash', () {
      const code = 'function test() { return "hello"; }';

      final hash1 = analyzer.generateCodeHash(code);
      final hash2 = analyzer.generateCodeHash(code);

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 produces 64 hex characters
    });

    test('Compares reports correctly', () {
      const code1 = 'eval(userInput);';
      const code2 = 'localStorage.setItem("key", "value");';

      final report1 = analyzer.analyzeCode(code1, 'test1.js');
      final report2 = analyzer.analyzeCode(code2, 'test2.js');

      final comparison = analyzer.compareReports(report1, report2);

      expect(comparison.containsKey('fixedIssues'), isTrue);
      expect(comparison.containsKey('introducedIssues'), isTrue);
      expect(comparison.containsKey('scoreChange'), isTrue);
      expect(comparison.containsKey('improvement'), isTrue);
    });

    test('Detects document.write usage', () {
      const code = '''
        document.write('<h1>Hello</h1>');
      ''';

      final report = analyzer.analyzeCode(code, 'test.js');

      expect(
        report.issues.any((issue) => issue.title.contains('document.write')),
        isTrue,
      );
    });

    test('Detects multiple security issues', () {
      const code = '''
        function dangerous() {
          eval(userInput);
          document.write(content);
          localStorage.setItem('token', secret);
          fetch('http://insecure.com/data');
        }
      ''';

      final report = analyzer.analyzeCode(code, 'test.js');

      expect(report.issues.length, greaterThan(3));
      expect(report.criticalIssues, greaterThan(0));
      expect(report.highIssues, greaterThan(0));
      expect(report.mediumIssues, greaterThan(0));
    });

    test('Handles empty code', () {
      const code = '';

      final report = analyzer.analyzeCode(code, 'empty.js');

      expect(report.issues.isEmpty, isTrue);
      expect(report.codeQualityScore, equals(100));
    });

    test('Includes line numbers in issues', () {
      const code = '''
        line 1
        line 2
        eval(userInput);
        line 4
      ''';

      final report = analyzer.analyzeCode(code, 'test.js');

      final evalIssue = report.issues.firstWhere(
        (issue) => issue.title.contains('eval'),
        orElse: () => throw Exception('eval issue not found'),
      );

      expect(evalIssue.lineNumber, equals(3));
    });

    test('Provides recommendations', () {
      const code = 'eval(userInput);';

      final report = analyzer.analyzeCode(code, 'test.js');

      expect(report.issues.isNotEmpty, isTrue);

      for (var issue in report.issues) {
        expect(issue.recommendation.isNotEmpty, isTrue);
        expect(issue.description.isNotEmpty, isTrue);
      }
    });
  });

  group('SecurityReport Tests', () {
    test('Correctly counts issues by severity', () {
      final issues = [
        SecurityIssue(
          severity: 'critical',
          title: 'Critical issue',
          description: 'A critical security issue',
          recommendation: 'Fix it',
        ),
        SecurityIssue(
          severity: 'high',
          title: 'High issue',
          description: 'A high severity issue',
          recommendation: 'Fix it',
        ),
        SecurityIssue(
          severity: 'medium',
          title: 'Medium issue',
          description: 'A medium severity issue',
          recommendation: 'Fix it',
        ),
        SecurityIssue(
          severity: 'low',
          title: 'Low issue',
          description: 'A low severity issue',
          recommendation: 'Fix it',
        ),
      ];

      final report = SecurityReport(
        issues: issues,
        codeQualityScore: 50,
        timestamp: DateTime.now(),
        analyzedFile: 'test.js',
      );

      expect(report.criticalIssues, equals(1));
      expect(report.highIssues, equals(1));
      expect(report.mediumIssues, equals(1));
      expect(report.lowIssues, equals(1));
    });

    test('Serializes to JSON correctly', () {
      final issue = SecurityIssue(
        severity: 'critical',
        title: 'Test issue',
        description: 'Test description',
        recommendation: 'Fix it',
        lineNumber: 10,
        codeSnippet: 'test code',
      );

      final json = issue.toJson();

      expect(json['severity'], equals('critical'));
      expect(json['title'], equals('Test issue'));
      expect(json['description'], equals('Test description'));
      expect(json['lineNumber'], equals(10));
      expect(json['codeSnippet'], equals('test code'));
      expect(json['recommendation'], equals('Fix it'));
    });
  });
}
