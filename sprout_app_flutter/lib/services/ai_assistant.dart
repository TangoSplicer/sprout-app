class AIAssistant {
  static final AIAssistant _instance = AIAssistant._internal();

  factory AIAssistant() => _instance;

  AIAssistant._internal();

  Future<String> generate(String prompt) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final normalizedPrompt = prompt.toLowerCase();
    if (normalizedPrompt.contains('todo') ||
        normalizedPrompt.contains('to-do')) {
      return _rankedTodoTemplate;
    }
    if (normalizedPrompt.contains('counter')) {
      return _counterTemplate;
    }
    if (normalizedPrompt.contains('navigate') ||
        normalizedPrompt.contains('go to')) {
      return _navigationTemplate;
    }

    return _starterTemplate;
  }

  static const String _rankedTodoTemplate = '''app "Ranked Todo" {
  start = "Todo"
}

screen Todo {
  state rank: 1
  ui {
    label "My ranked tasks"
    label "1. Plan today"
    label "2. Finish the important task"
    label "3. Review tomorrow"
    button "Add task"
    button "Mark top task complete"
  }
}''';

  static const String _counterTemplate = '''app "Counter" {
  start = "Counter"
}

screen Counter {
  state count: 0
  ui {
    label "Counter"
    label "Current count: \${count}"
    button "Increase"
    button "Decrease"
  }
}''';

  static const String _navigationTemplate = '''app "Simple Navigator" {
  start = "Home"
}

screen Home {
  ui {
    label "Welcome to your app"
    button "Open settings"
  }
}

screen Settings {
  ui {
    label "Settings"
    button "Back"
  }
}''';

  static const String _starterTemplate = '''app "My Sprout App" {
  start = "Home"
}

screen Home {
  ui {
    label "Your new app is ready"
    label "Describe a todo list, counter, or navigation app for a tailored starter."
    button "Get started"
  }
}''';
}
