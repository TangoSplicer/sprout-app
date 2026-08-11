// flutter/lib/services/navigation_engine.dart
import 'package:flutter/material.dart';

class NavigationEngine {
  final Map<String, String> screenCode;
  final Function(String) onNavigate;

  NavigationEngine({required this.screenCode, required this.onNavigate});

  Widget parseAndBuild(String code, {String screenName = 'Home'}) {
    final screenBody = _extractScreen(code, screenName);
    if (screenBody == null) return const Text('Screen not found');

    final label = _extractLabel(screenBody) ?? 'No label';
    final buttonLabel = _extractButtonLabel(screenBody) ?? 'Next';
    final navTarget = _extractNavigation(screenBody);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            if (navTarget != null) {
              onNavigate(navTarget);
            }
          },
          child: Text(buttonLabel),
        ),
      ],
    );
  }

  String? _extractScreen(String code, String name) {
    final pattern = RegExp(r'screen $name\s*{([^}]+)}', multiLine: true);
    return pattern.firstMatch(code)?.group(1);
  }

  String? _extractLabel(String screen) {
    final match = RegExp(r'label\("([^"]+)"\)').firstMatch(screen);
    return match?.group(1);
  }

  String? _extractButtonLabel(String screen) {
    final match = RegExp(r'button\("([^"]+)"\)').firstMatch(screen);
    return match?.group(1);
  }

  String? _extractNavigation(String screen) {
    final match = RegExp(r'->\s*(\w+)').firstMatch(screen);
    return match?.group(1);
  }
}