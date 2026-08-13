/// Produces safe, executable SproutScript starters from a person’s description.
///
/// This local planner intentionally does not claim to be a remote LLM. It uses
/// the request to select a useful interaction pattern and carries the user’s
/// own words into the project title and guidance so each generated result is
/// inspectable, distinct, and valid for the supported runtime.
class AIAssistant {
  static final AIAssistant _instance = AIAssistant._internal();

  factory AIAssistant() => _instance;

  AIAssistant._internal();

  Future<String> generate(String prompt) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final request = _normalise(prompt);
    final category = _categoryFor(request.toLowerCase());
    final appName = _appNameFor(request, category);

    return switch (category) {
      _AppCategory.navigation => _navigationTemplate(appName, request),
      _AppCategory.todo => _collectionTemplate(
          appName: appName,
          heading: 'Your ranked tasks',
          guidance: 'Add a task, then complete the first item when it is done.',
          inputLabel: 'Task to rank',
          listName: 'tasks',
          addLabel: 'Add task',
          completeLabel: 'Complete first task',
          settingsTitle: 'Task settings',
        ),
      _AppCategory.shopping => _collectionTemplate(
          appName: appName,
          heading: 'Shopping list',
          guidance:
              'Add what you need, then remove the first item once it is in the basket.',
          inputLabel: 'Item to buy',
          listName: 'items',
          addLabel: 'Add item',
          completeLabel: 'Remove first item',
          settingsTitle: 'Shopping settings',
        ),
      _AppCategory.notes => _collectionTemplate(
          appName: appName,
          heading: 'Quick notes',
          guidance:
              'Capture a thought, then remove the first note once you have used it.',
          inputLabel: 'Write a note',
          listName: 'notes',
          addLabel: 'Save note',
          completeLabel: 'Archive first note',
          settingsTitle: 'Notes settings',
        ),
      _AppCategory.habit => _collectionTemplate(
          appName: appName,
          heading: 'Habit check-in',
          guidance:
              'Add a habit to focus on and clear the first one after you check in.',
          inputLabel: 'Habit to practise',
          listName: 'habits',
          addLabel: 'Add habit',
          completeLabel: 'Complete first habit',
          settingsTitle: 'Habit settings',
        ),
      _AppCategory.general => _collectionTemplate(
          appName: appName,
          heading: 'A small app for you',
          guidance: 'Built from your idea: $request',
          inputLabel: 'Add an item',
          listName: 'items',
          addLabel: 'Add item',
          completeLabel: 'Remove first item',
          settingsTitle: 'App settings',
        ),
    };
  }

  static String _normalise(String prompt) {
    final compact = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) {
      return 'a simple personal organiser';
    }
    final sanitized = compact
        .replaceAll('"', "'")
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll(r'$', '')
        .replaceAll(';', ',');
    final maximumLength = sanitized.length > 140 ? 140 : sanitized.length;
    return sanitized.substring(0, maximumLength);
  }

  static _AppCategory _categoryFor(String prompt) {
    if (RegExp(r'\b(todo|to-do|task|priority|rank|chore)\b').hasMatch(prompt)) {
      return _AppCategory.todo;
    }
    if (RegExp(r'\b(shop|shopping|grocery|groceries|basket)\b')
        .hasMatch(prompt)) {
      return _AppCategory.shopping;
    }
    if (RegExp(r'\b(note|journal|idea|thought)\b').hasMatch(prompt)) {
      return _AppCategory.notes;
    }
    if (RegExp(r'\b(habit|routine|exercise|meditat)\b').hasMatch(prompt)) {
      return _AppCategory.habit;
    }
    if (RegExp(r'\b(navigate|navigation|settings|screen|page)\b')
        .hasMatch(prompt)) {
      return _AppCategory.navigation;
    }
    return _AppCategory.general;
  }

  static String _appNameFor(String request, _AppCategory category) {
    final words = request
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(4)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
    final suffix = switch (category) {
      _AppCategory.todo => 'Tasks',
      _AppCategory.shopping => 'List',
      _AppCategory.notes => 'Notes',
      _AppCategory.habit => 'Habits',
      _AppCategory.navigation => 'Navigator',
      _AppCategory.general => 'Sprout',
    };
    return words.isEmpty ? 'My $suffix' : '$words $suffix';
  }

  static String _collectionTemplate({
    required String appName,
    required String heading,
    required String guidance,
    required String inputLabel,
    required String listName,
    required String addLabel,
    required String completeLabel,
    required String settingsTitle,
  }) =>
      '''app "$appName" {
  start = "Home"
}

screen Home {
  state draft: ""
  state $listName: []
  ui {
    label "$heading"
    label "$guidance"
    input "$inputLabel" -> draft
    list $listName
    button "$addLabel" {
      $listName.append(draft)
      draft = ""
    }
    button "$completeLabel" {
      $listName.remove_first()
    }
    button "Open settings" -> Settings
  }
}

screen Settings {
  ui {
    label "$settingsTitle"
    label "Your app is stored locally on this device."
    button "Back to your list" { go Back }
  }
}''';

  static String _navigationTemplate(String appName, String request) =>
      '''app "$appName" {
  start = "Welcome"
}

screen Welcome {
  ui {
    label "Welcome"
    label "This app was planned for: $request"
    button "Open details" -> Details
  }
}

screen Details {
  ui {
    label "Details"
    label "This second screen proves navigation is working."
    button "Back" { go Back }
  }
}''';
}

enum _AppCategory { todo, shopping, notes, habit, navigation, general }
