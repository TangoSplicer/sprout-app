// flutter/lib/services/ai_assistant.dart
import 'dart:convert';

class AIAssistant {
  static final AIAssistant _instance = AIAssistant._internal();
  factory AIAssistant() => _instance;
  AIAssistant._internal();

  Future<String> generate(String prompt) async {
    await Future.delayed(const Duration(seconds: 2));

    prompt = prompt.toLowerCase();

    if (prompt.contains('todo') || prompt.contains('to-do')) {
      return '''screen TodoList {
  state todos = []

  ui {
    list(todos) {
      button("Done") { todos.remove(item) }
    }
    button("Add") -> AddTodo
  }
}

screen AddTodo {
  state input = ""
  ui {
    input("New item", text: input)
    button("Save") {
      if input != "" {
        todos.add(input)
        input = ""
      }
      go Back
    }
  }
}''';
    }

    if (prompt.contains('counter')) {
      return '''screen Counter {
  state count = 0
  ui {
    column {
      title("Counter")
      label("\${count}")
      button("++") { count = count + 1 }
      button("--") { count = count - 1 }
    }
  }
}''';
    }

    if (prompt.contains('navigate') || prompt.contains('go to')) {
      return '''screen Home {
  ui {
    label("Welcome!")
    button("Open Settings") -> Settings
  }
}

screen Settings {
  ui {
    label("This is the settings screen")
    button("Back") -> Back
  }
}''';
    }

    return '''// Try: "todo", "counter", or "navigate"
screen Help {
  ui {
    label("Describe what you want.")
  }
}''';
  }
}