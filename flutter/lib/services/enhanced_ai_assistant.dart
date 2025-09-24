// flutter/lib/services/enhanced_ai_assistant.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

/// Result of AI code generation
class AIGenerationResult {
  final String code;
  final String explanation;
  final bool isSuccess;
  final String? error;

  AIGenerationResult({
    required this.code,
    required this.explanation,
    this.isSuccess = true,
    this.error,
  });

  factory AIGenerationResult.error(String error) {
    return AIGenerationResult(
      code: '// Error: $error',
      explanation: 'Failed to generate code: $error',
      isSuccess: false,
      error: error,
    );
  }
}

/// Template for code generation
class CodeTemplate {
  final String name;
  final String description;
  final String code;
  final List<String> keywords;
  final List<String> requiredParams;
  final Map<String, String> optionalParams;

  CodeTemplate({
    required this.name,
    required this.description,
    required this.code,
    required this.keywords,
    this.requiredParams = const [],
    this.optionalParams = const {},
  });
}

/// Enhanced AI Assistant for code generation
class EnhancedAIAssistant {
  static final EnhancedAIAssistant _instance = EnhancedAIAssistant._internal();
  factory EnhancedAIAssistant() => _instance;
  
  // Templates for code generation
  final List<CodeTemplate> _templates = [
    CodeTemplate(
      name: 'Todo List',
      description: 'A simple todo list app with add and remove functionality',
      keywords: ['todo', 'to-do', 'list', 'task', 'checklist'],
      requiredParams: [],
      optionalParams: {
        'title': 'Todo List',
        'itemName': 'task',
      },
      code: '''app "{{title}}" {
  start = TodoList
}

screen TodoList {
  state todos = []
  state newItem = ""

  ui {
    column {
      title("{{title}}")
      
      // Input for new items
      row {
        input("New {{itemName}}", binding: newItem)
        button("Add") {
          if newItem != "" {
            todos.add(newItem)
            newItem = ""
          }
        }
      }
      
      // List of todos
      if todos.length > 0 {
        list(todos) {
          row {
            label(item)
            button("Done") {
              todos.remove(item)
            }
          }
        }
      } else {
        label("No {{itemName}}s yet")
      }
    }
  }
}''',
    ),
    
    CodeTemplate(
      name: 'Counter',
      description: 'A simple counter app with increment and decrement buttons',
      keywords: ['counter', 'count', 'increment', 'decrement', 'number'],
      requiredParams: [],
      optionalParams: {
        'title': 'Counter',
        'initialValue': '0',
      },
      code: '''app "{{title}}" {
  start = Counter
}

screen Counter {
  state count = {{initialValue}}
  
  ui {
    column {
      title("{{title}}")
      
      // Display the count
      label("\${count}", size: 48, bold)
      
      // Buttons
      row {
        button("--") { count = count - 1 }
        button("++") { count = count + 1 }
      }
      
      // Reset button
      button("Reset") { count = {{initialValue}} }
    }
  }
}''',
    ),
    
    CodeTemplate(
      name: 'Navigation',
      description: 'A multi-screen app with navigation between screens',
      keywords: ['navigate', 'navigation', 'screens', 'go to', 'multi-screen'],
      requiredParams: [],
      optionalParams: {
        'appName': 'Navigation Demo',
        'screen1': 'Home',
        'screen2': 'Details',
      },
      code: '''app "{{appName}}" {
  start = {{screen1}}
}

screen {{screen1}} {
  ui {
    column {
      title("{{screen1}}")
      label("Welcome to the {{appName}} app!")
      button("Go to {{screen2}}") -> {{screen2}}
    }
  }
}

screen {{screen2}} {
  ui {
    column {
      title("{{screen2}}")
      label("This is the {{screen2}} screen")
      button("Back to {{screen1}}") -> Back
    }
  }
}''',
    ),
    
    CodeTemplate(
      name: 'Note Taking',
      description: 'A note-taking app with create, view, and delete functionality',
      keywords: ['note', 'notes', 'notepad', 'memo', 'write'],
      requiredParams: [],
      optionalParams: {
        'title': 'Notes',
      },
      code: '''app "{{title}}" {
  start = NotesList
}

screen NotesList {
  state notes = []
  
  ui {
    column {
      title("{{title}}")
      
      // Add new note button
      button("New Note") -> EditNote("")
      
      // List of notes
      if notes.length > 0 {
        list(notes) {
          button(item.title) -> ViewNote(item)
        }
      } else {
        label("No notes yet")
      }
    }
  }
}

screen ViewNote(note) {
  ui {
    column {
      title(note.title)
      label(note.content)
      
      row {
        button("Edit") -> EditNote(note)
        button("Delete") {
          notes.remove(note)
          go Back
        }
      }
      
      button("Back") -> Back
    }
  }
}

screen EditNote(note) {
  state title = note ? note.title : ""
  state content = note ? note.content : ""
  
  ui {
    column {
      title(note ? "Edit Note" : "New Note")
      
      input("Title", binding: title)
      input("Content", binding: content, multiline: true)
      
      button("Save") {
        if title != "" {
          if note {
            // Update existing note
            note.title = title
            note.content = content
          } else {
            // Create new note
            notes.add({
              title: title,
              content: content
            })
          }
          go Back
        }
      }
      
      button("Cancel") -> Back
    }
  }
}''',
    ),
    
    CodeTemplate(
      name: 'Habit Tracker',
      description: 'A habit tracking app to monitor daily habits',
      keywords: ['habit', 'tracker', 'daily', 'routine', 'track'],
      requiredParams: [],
      optionalParams: {
        'title': 'Habit Tracker',
      },
      code: '''app "{{title}}" {
  start = HabitList
}

screen HabitList {
  state habits = []
  state today = Date.today()
  
  ui {
    column {
      title("{{title}}")
      
      // Date display
      label("\${today.format('MMMM d, yyyy')}", size: 18)
      
      // Add new habit button
      button("Add Habit") -> AddHabit
      
      // List of habits
      if habits.length > 0 {
        list(habits) {
          row {
            label(item.name)
            checkbox(item.completed) {
              item.completed = !item.completed
              if item.completed {
                item.streak += 1
              } else {
                item.streak = max(0, item.streak - 1)
              }
            }
            label("Streak: \${item.streak}")
          }
        }
      } else {
        label("No habits yet")
      }
    }
  }
  
  onLaunch {
    // Reset completion status at midnight
    every 1d at 00:00 {
      for habit in habits {
        habit.completed = false
      }
      today = Date.today()
    }
  }
}

screen AddHabit {
  state name = ""
  
  ui {
    column {
      title("Add Habit")
      
      input("Habit name", binding: name)
      
      button("Save") {
        if name != "" {
          habits.add({
            name: name,
            completed: false,
            streak: 0
          })
          go Back
        }
      }
      
      button("Cancel") -> Back
    }
  }
}''',
    ),
  ];
  
  EnhancedAIAssistant._internal();

  /// Generate code based on a prompt
  Future<AIGenerationResult> generate(String prompt) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Normalize prompt
      final normalizedPrompt = prompt.toLowerCase().trim();
      
      // Find matching templates
      final matchingTemplates = _findMatchingTemplates(normalizedPrompt);
      
      if (matchingTemplates.isEmpty) {
        return AIGenerationResult(
          code: _generateHelpCode(),
          explanation: 'I couldn\'t find a template matching your request. Try describing what you want to build, like "todo list", "counter", or "note taking app".',
          isSuccess: true,
        );
      }
      
      // Use the best matching template
      final template = matchingTemplates.first;
      
      // Extract parameters from prompt
      final params = _extractParams(normalizedPrompt, template);
      
      // Generate code from template
      final code = _generateFromTemplate(template, params);
      
      return AIGenerationResult(
        code: code,
        explanation: 'I generated a ${template.name} app based on your request. ${template.description}.',
        isSuccess: true,
      );
    } catch (e) {
      return AIGenerationResult.error(e.toString());
    }
  }
  
  /// Find templates matching the prompt
  List<CodeTemplate> _findMatchingTemplates(String prompt) {
    // Calculate match score for each template
    final scores = <CodeTemplate, int>{};
    
    for (final template in _templates) {
      int score = 0;
      
      // Check for keyword matches
      for (final keyword in template.keywords) {
        if (prompt.contains(keyword)) {
          score += 10;
        }
      }
      
      scores[template] = score;
    }
    
    // Sort templates by score (descending)
    final sortedTemplates = _templates.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    
    // Return templates with non-zero scores
    return sortedTemplates.where((t) => scores[t]! > 0).toList();
  }
  
  /// Extract parameters from prompt
  Map<String, String> _extractParams(String prompt, CodeTemplate template) {
    final params = <String, String>{};
    
    // Start with default values for optional parameters
    params.addAll(template.optionalParams);
    
    // TODO: In a real implementation, we would use NLP to extract parameters
    // For now, we'll use some simple heuristics
    
    // Extract title if mentioned
    final titleMatch = RegExp(r'called\s+["\']?([^"\']+)["\']?').firstMatch(prompt);
    if (titleMatch != null && params.containsKey('title')) {
      params['title'] = titleMatch.group(1)!;
    }
    
    // Extract initial value for counter
    final initialValueMatch = RegExp(r'start(?:ing)?\s+(?:at|with)\s+(\d+)').firstMatch(prompt);
    if (initialValueMatch != null && params.containsKey('initialValue')) {
      params['initialValue'] = initialValueMatch.group(1)!;
    }
    
    return params;
  }
  
  /// Generate code from template
  String _generateFromTemplate(CodeTemplate template, Map<String, String> params) {
    String code = template.code;
    
    // Replace parameters
    for (final entry in params.entries) {
      code = code.replaceAll('{{${entry.key}}}', entry.value);
    }
    
    return code;
  }
  
  /// Generate help code when no template matches
  String _generateHelpCode() {
    return '''app "Sprout Help" {
  start = Help
}

screen Help {
  ui {
    column {
      title("Sprout Help")
      label("Try asking for one of these:")
      
      // List of available templates
      label("• Todo list")
      label("• Counter")
      label("• Navigation demo")
      label("• Note taking app")
      label("• Habit tracker")
      
      label("For example: 'Create a todo list called My Tasks'")
    }
  }
}''';
  }
  
  /// Get all available templates
  List<CodeTemplate> getTemplates() {
    return List.unmodifiable(_templates);
  }
  
  /// Add a custom template
  void addTemplate(CodeTemplate template) {
    _templates.add(template);
  }
}