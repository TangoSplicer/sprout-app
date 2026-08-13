/// Produces safe, executable SproutScript starters from a person’s description.
///
/// The first release deliberately uses an on-device planner rather than claiming
/// to call a cloud model. It recognises concrete capabilities in the request and
/// emits only language features supported by the bounded compiler and preview
/// runtime. This makes the generated result inspectable, editable, and usable
/// when the device is offline.
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
      _AppCategory.reminders => _reminderTemplate(appName, request),
      _AppCategory.eventPlanner => _eventPlannerTemplate(appName, request),
      _AppCategory.navigation => _navigationTemplate(appName, request),
      _AppCategory.todo => _taskTemplate(appName, request),
      _AppCategory.shopping => _shoppingTemplate(appName, request),
      _AppCategory.notes => _notesTemplate(appName, request),
      _AppCategory.habit => _habitTemplate(appName, request),
      _AppCategory.general => _ideaTemplate(appName, request),
    };
  }

  static String _normalise(String prompt) {
    final compact = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return 'a simple personal organiser';
    final sanitized = compact
        .replaceAll('"', "'")
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll(r'$', '')
        .replaceAll(';', ',');
    return sanitized.substring(0, sanitized.length.clamp(0, 140));
  }

  static _AppCategory _categoryFor(String prompt) {
    final hasReminder = RegExp(
      r'\b(alarm|alarms|remind|reminder|reminders|notification|notifications|alert|alerts|timer|timers)\b',
    ).hasMatch(prompt);
    if (hasReminder &&
        RegExp(r'\b(event|events|meeting|meetings|appointment|appointments|calendar)\b')
            .hasMatch(prompt)) {
      return _AppCategory.eventPlanner;
    }
    if (hasReminder) return _AppCategory.reminders;
    if (RegExp(r'\b(todo|to-do|task|tasks|priority|rank|chore|chores)\b')
        .hasMatch(prompt)) {
      return _AppCategory.todo;
    }
    if (RegExp(r'\b(shop|shopping|grocery|groceries|basket|buy)\b')
        .hasMatch(prompt)) {
      return _AppCategory.shopping;
    }
    if (RegExp(r'\b(note|notes|journal|idea|ideas|thought|thoughts)\b')
        .hasMatch(prompt)) {
      return _AppCategory.notes;
    }
    if (RegExp(r'\b(habit|routine|exercise|meditat|streak)\b')
        .hasMatch(prompt)) {
      return _AppCategory.habit;
    }
    if (RegExp(r'\b(navigate|navigation|settings|screen|screens|page|pages)\b')
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
      _AppCategory.reminders => 'Reminders',
      _AppCategory.eventPlanner => 'Planner',
      _AppCategory.todo => 'Tasks',
      _AppCategory.shopping => 'List',
      _AppCategory.notes => 'Notes',
      _AppCategory.habit => 'Habits',
      _AppCategory.navigation => 'Navigator',
      _AppCategory.general => 'Sprout',
    };
    return words.isEmpty ? 'My $suffix' : '$words $suffix';
  }

  static String _taskTemplate(String appName, String request) =>
      _collectionTemplate(
        appName: appName,
        request: request,
        screenName: 'Tasks',
        heading: 'Your ranked tasks',
        guidance: 'Built for: $request',
        inputLabel: 'Task to rank',
        listName: 'tasks',
        draftName: 'taskDraft',
        addLabel: 'Add at the bottom',
        completeLabel: 'Complete top task',
        detailsTitle: 'Task workflow',
      );

  static String _shoppingTemplate(String appName, String request) =>
      _collectionTemplate(
        appName: appName,
        request: request,
        screenName: 'Shopping',
        heading: 'Shopping list',
        guidance: 'Keep your next purchase clear and simple.',
        inputLabel: 'Item to buy',
        listName: 'basket',
        draftName: 'itemDraft',
        addLabel: 'Add to basket',
        completeLabel: 'Cross off first item',
        detailsTitle: 'Shopping plan',
      );

  static String _notesTemplate(String appName, String request) =>
      _collectionTemplate(
        appName: appName,
        request: request,
        screenName: 'Notes',
        heading: 'Quick notes',
        guidance: 'Capture the thought before it disappears.',
        inputLabel: 'Write a note',
        listName: 'notes',
        draftName: 'noteDraft',
        addLabel: 'Save note',
        completeLabel: 'Archive first note',
        detailsTitle: 'Notes archive',
      );

  static String _habitTemplate(String appName, String request) =>
      _collectionTemplate(
        appName: appName,
        request: request,
        screenName: 'Habits',
        heading: 'Habit check-in',
        guidance: 'One small, repeatable step is enough today.',
        inputLabel: 'Habit to practise',
        listName: 'habits',
        draftName: 'habitDraft',
        addLabel: 'Add a habit',
        completeLabel: 'Mark first habit done',
        detailsTitle: 'Habit progress',
      );

  static String _ideaTemplate(String appName, String request) =>
      _collectionTemplate(
        appName: appName,
        request: request,
        screenName: 'Home',
        heading: 'A small app for your idea',
        guidance: 'Starting point for: $request',
        inputLabel: 'Add something useful',
        listName: 'ideas',
        draftName: 'ideaDraft',
        addLabel: 'Keep this idea',
        completeLabel: 'Clear first idea',
        detailsTitle: 'About this app',
      );

  static String _collectionTemplate({
    required String appName,
    required String request,
    required String screenName,
    required String heading,
    required String guidance,
    required String inputLabel,
    required String listName,
    required String draftName,
    required String addLabel,
    required String completeLabel,
    required String detailsTitle,
  }) =>
      '''app "$appName" {
  start = "$screenName"
}

screen $screenName {
  state $draftName: ""
  state $listName: []
  ui {
    label "$heading"
    label "$guidance"
    input "$inputLabel" -> $draftName
    list $listName
    button "$addLabel" {
      $listName.append($draftName)
      $draftName = ""
    }
    button "$completeLabel" {
      $listName.remove_first()
    }
    button "How this app works" -> Details
  }
}

screen Details {
  ui {
    label "$detailsTitle"
    label "This starter was planned from: $request"
    button "Back" { go Back }
  }
}''';

  static String _reminderTemplate(String appName, String request) =>
      '''app "$appName" {
  start = "Reminders"
}

screen Reminders {
  state reminderText: ""
  state reminderTime: "09:00"
  state scheduled: []
  ui {
    label "Reminders that fit your day"
    label "Built for: $request"
    input "What should Sprout remind you about?" -> reminderText
    input "Time in 24-hour format, for example 09:00" -> reminderTime
    button "Schedule reminder" {
      scheduled.append("\${reminderText} at \${reminderTime}")
      reminder reminderText at reminderTime
    }
    list scheduled
    button "Reminder help" -> Help
  }
}

screen Help {
  ui {
    label "Set a time such as 09:00 or 18:30."
    label "Sprout asks for notification permission only when you schedule."
    button "Back to reminders" { go Back }
  }
}''';

  static String _eventPlannerTemplate(String appName, String request) =>
      '''app "$appName" {
  start = "Events"
}

screen Events {
  state eventName: ""
  state eventTime: "09:00"
  state events: []
  ui {
    label "Event planner with reminders"
    label "Built for: $request"
    input "Event or appointment" -> eventName
    input "Start time in 24-hour format" -> eventTime
    button "Add event and reminder" {
      events.append("\${eventName} at \${eventTime}")
      reminder eventName at eventTime
      eventName = ""
    }
    list events
    button "Planning tips" -> Tips
  }
}

screen Tips {
  ui {
    label "Each event is saved in your list and schedules a local reminder."
    button "Back to events" { go Back }
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
    button "Open your workspace" -> Workspace
    button "Open settings" -> Settings
  }
}

screen Workspace {
  state draft: ""
  state items: []
  ui {
    label "Your workspace"
    input "Add an item" -> draft
    button "Save item" {
      items.append(draft)
      draft = ""
    }
    list items
    button "Back home" { go Back }
  }
}

screen Settings {
  ui {
    label "Settings"
    label "A separate settings screen is ready for your next step."
    button "Back home" { go Back }
  }
}''';
}

enum _AppCategory {
  reminders,
  eventPlanner,
  todo,
  shopping,
  notes,
  habit,
  navigation,
  general,
}
