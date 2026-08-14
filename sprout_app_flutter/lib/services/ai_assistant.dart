/// Produces safe, executable, and editable SproutScript apps from a person’s
/// description.
///
/// This on-device planner does not pretend to be a cloud model. It turns intent
/// and requested capabilities into bounded language primitives that the compiler
/// and interactive preview understand. Every branch creates a distinct app shape
/// rather than merely changing labels on the same screen.
class AIAssistant {
  static final AIAssistant _instance = AIAssistant._internal();

  factory AIAssistant() => _instance;

  AIAssistant._internal();

  Future<String> generate(String prompt) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final request = _normalise(prompt);
    final category = _categoryFor(request.toLowerCase());
    final plan = _AppPlan.fromRequest(request, category);

    return switch (category) {
      _AppCategory.reminders => _reminderApp(plan),
      _AppCategory.eventPlanner => _eventPlannerApp(plan),
      _AppCategory.focus => _focusApp(plan),
      _AppCategory.wellness => _wellnessApp(plan),
      _AppCategory.budget => _budgetApp(plan),
      _AppCategory.meals => _mealPlannerApp(plan),
      _AppCategory.reading => _readingApp(plan),
      _AppCategory.navigation => _workspaceApp(plan),
      _AppCategory.todo => _collectionApp(
          plan,
          screenName: 'Today',
          heroTitle: 'Your priority board',
          heroDetail: 'A focused plan for ${plan.subject}.',
          metricLabel: 'Tasks completed',
          inputLabel: 'Add a meaningful task',
          listName: 'tasks',
          draftName: 'taskDraft',
          countName: 'completed',
          preferenceLabel: 'Show a calm completion prompt',
          addLabel: 'Add to today',
          completeLabel: 'Complete next task',
          archiveLabel: 'Clear completed plan',
          detailsTitle: 'A better way to plan',
        ),
      _AppCategory.shopping => _collectionApp(
          plan,
          screenName: 'Shopping',
          heroTitle: 'Your considered shopping list',
          heroDetail: 'Keep ${plan.subject} practical and intentional.',
          metricLabel: 'Items added',
          inputLabel: 'Add an item to buy',
          listName: 'basket',
          draftName: 'itemDraft',
          countName: 'itemsAdded',
          preferenceLabel: 'Group the next shopping trip',
          addLabel: 'Add to basket',
          completeLabel: 'Cross off next item',
          archiveLabel: 'Clear this shopping trip',
          detailsTitle: 'Shopping flow',
        ),
      _AppCategory.notes => _collectionApp(
          plan,
          screenName: 'Capture',
          heroTitle: 'A home for your ideas',
          heroDetail: 'Capture ${plan.subject} before it slips away.',
          metricLabel: 'Notes saved',
          inputLabel: 'Write the note in your own words',
          listName: 'notes',
          draftName: 'noteDraft',
          countName: 'notesSaved',
          preferenceLabel: 'Keep this capture space distraction-free',
          addLabel: 'Save this thought',
          completeLabel: 'Archive the next note',
          archiveLabel: 'Clear the capture list',
          detailsTitle: 'Your note ritual',
        ),
      _AppCategory.habit => _collectionApp(
          plan,
          screenName: 'Routine',
          heroTitle: 'A smaller, repeatable routine',
          heroDetail: 'Build ${plan.subject} one check-in at a time.',
          metricLabel: 'Check-ins completed',
          inputLabel: 'Name a small habit',
          listName: 'habits',
          draftName: 'habitDraft',
          countName: 'checkIns',
          preferenceLabel: 'Keep a gentle daily nudge',
          addLabel: 'Add this habit',
          completeLabel: 'Mark next habit done',
          archiveLabel: 'Reset this routine',
          detailsTitle: 'Routine design',
        ),
      _AppCategory.general => _workspaceApp(plan),
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
    return sanitized.substring(0, sanitized.length.clamp(0, 180));
  }

  static _AppCategory _categoryFor(String request) {
    final hasFocusIntent = RegExp(
            r'\b(focus|pomodoro|deep work|study|studying|concentration|session)\b')
        .hasMatch(request);
    if (hasFocusIntent) return _AppCategory.focus;

    final hasReminder = RegExp(
      r'\b(alarm|alarms|remind|reminder|reminders|notification|notifications|alert|alerts|timer|timers)\b',
    ).hasMatch(request);
    if (hasReminder &&
        RegExp(r'\b(event|events|meeting|meetings|appointment|appointments|calendar)\b')
            .hasMatch(request)) {
      return _AppCategory.eventPlanner;
    }
    if (hasReminder) return _AppCategory.reminders;
    if (RegExp(
            r'\b(water|wellness|mood|sleep|workout|fitness|meditat|health)\b')
        .hasMatch(request)) {
      return _AppCategory.wellness;
    }
    if (RegExp(
            r'\b(budget|expense|expenses|spend|spending|saving|savings|money)\b')
        .hasMatch(request)) {
      return _AppCategory.budget;
    }
    if (RegExp(r'\b(meal|meals|recipe|recipes|dinner|lunch|breakfast|food)\b')
        .hasMatch(request)) {
      return _AppCategory.meals;
    }
    if (RegExp(r'\b(read|reading|book|books|library)\b').hasMatch(request)) {
      return _AppCategory.reading;
    }
    if (RegExp(r'\b(todo|to-do|task|tasks|priority|rank|chore|chores)\b')
        .hasMatch(request)) {
      return _AppCategory.todo;
    }
    if (RegExp(r'\b(shop|shopping|grocery|groceries|basket|buy)\b')
        .hasMatch(request)) {
      return _AppCategory.shopping;
    }
    if (RegExp(r'\b(note|notes|journal|idea|ideas|thought|thoughts)\b')
        .hasMatch(request)) {
      return _AppCategory.notes;
    }
    if (RegExp(r'\b(habit|routine|exercise|streak)\b').hasMatch(request)) {
      return _AppCategory.habit;
    }
    if (RegExp(r'\b(navigate|navigation|settings|screen|screens|page|pages)\b')
        .hasMatch(request)) {
      return _AppCategory.navigation;
    }
    return _AppCategory.general;
  }

  static String _collectionApp(
    _AppPlan plan, {
    required String screenName,
    required String heroTitle,
    required String heroDetail,
    required String metricLabel,
    required String inputLabel,
    required String listName,
    required String draftName,
    required String countName,
    required String preferenceLabel,
    required String addLabel,
    required String completeLabel,
    required String archiveLabel,
    required String detailsTitle,
  }) =>
      '''app "${plan.appName}" {
  start = "$screenName"
}

screen $screenName {
  state $draftName: ""
  state $listName: []
  state $countName: 0
  state calmMode: true
  ui {
    section "$heroTitle" "$heroDetail"
    metric "$metricLabel" -> $countName
    toggle "$preferenceLabel" -> calmMode
    divider
    input "$inputLabel" -> $draftName
    button "$addLabel" {
      $listName.append($draftName)
      increment $countName
      $draftName = ""
    }
    list $listName
    button "$completeLabel" {
      $listName.remove_first()
      increment $countName
    }
    button "$archiveLabel" { clear $listName }
    button "Make this flow yours" -> Details
  }
}

screen Details {
  ui {
    section "$detailsTitle" "Built specifically around ${plan.subject}."
    label "Your brief: ${plan.request}"
    label "Edit labels, actions, and screens to keep refining this app."
    button "Back to your app" { go Back }
  }
}''';

  static String _focusApp(_AppPlan plan) => '''app "${plan.appName}" {
  start = "Focus"
}

screen Focus {
  state sessions: 0
  state focusMinutes: 25
  state promptsPaused: false
  state distractions: []
  state distractionDraft: ""
  ui {
    section "A calmer focus session" "Designed around ${plan.subject}."
    metric "Sessions completed" -> sessions
    metric "Minutes per session" -> focusMinutes
    toggle "Pause gentle prompts" -> promptsPaused
    divider
    button "Finish a focus session" { increment sessions }
    button "Make the next session shorter" { increment focusMinutes by -5 }
    input "Capture a distraction, then return to work" -> distractionDraft
    button "Park this distraction" {
      distractions.append(distractionDraft)
      distractionDraft = ""
    }
    list distractions
    button "Clear distractions" { clear distractions }
    button "Focus guide" -> Guide
  }
}

screen Guide {
  ui {
    section "How this focus app works" "A simple cycle for ${plan.subject}."
    label "Finish a session, capture interruptions, and come back to what matters."
    button "Back to focus" { go Back }
  }
}''';

  static String _wellnessApp(_AppPlan plan) => '''app "${plan.appName}" {
  start = "CheckIn"
}

screen CheckIn {
  state checkIns: 0
  state remindersOn: true
  state reflection: ""
  state reflections: []
  ui {
    section "A small check-in for today" "Made for ${plan.subject}."
    metric "Check-ins complete" -> checkIns
    toggle "Keep a gentle daily reminder" -> remindersOn
    divider
    button "Log a positive check-in" { increment checkIns }
    input "What would help you feel better today?" -> reflection
    button "Keep this reflection" {
      reflections.append(reflection)
      reflection = ""
    }
    list reflections
    button "Clear reflections" { clear reflections }
    button "Wellness note" -> Note
  }
}

screen Note {
  ui {
    section "Progress without pressure" "One useful action is enough."
    label "This app keeps the focus on ${plan.subject}, not perfection."
    button "Back to check-in" { go Back }
  }
}''';

  static String _budgetApp(_AppPlan plan) => '''app "${plan.appName}" {
  start = "Budget"
}

screen Budget {
  state expensesLogged: 0
  state weeklyReview: true
  state expenseDraft: ""
  state expenses: []
  ui {
    section "Spend with more intention" "A personal view for ${plan.subject}."
    metric "Expenses logged" -> expensesLogged
    toggle "Keep a weekly review reminder" -> weeklyReview
    divider
    input "Describe an expense or saving decision" -> expenseDraft
    button "Log this decision" {
      expenses.append(expenseDraft)
      increment expensesLogged
      expenseDraft = ""
    }
    list expenses
    button "Remove the next entry" { expenses.remove_first() }
    button "Start a fresh review" { clear expenses }
    button "Budget reflection" -> Review
  }
}

screen Review {
  ui {
    section "Your money story" "Small observations make the next decision easier."
    label "This tracker was designed around ${plan.subject}."
    button "Back to budget" { go Back }
  }
}''';

  static String _mealPlannerApp(_AppPlan plan) => '''app "${plan.appName}" {
  start = "Meals"
}

screen Meals {
  state dinnersPlanned: 0
  state keepItSimple: true
  state mealDraft: ""
  state meals: []
  ui {
    section "Plan meals with less friction" "Built for ${plan.subject}."
    metric "Meals planned" -> dinnersPlanned
    toggle "Prefer quick, simple choices" -> keepItSimple
    divider
    input "Add a meal or recipe idea" -> mealDraft
    button "Plan this meal" {
      meals.append(mealDraft)
      increment dinnersPlanned
      mealDraft = ""
    }
    list meals
    button "Cook the next meal" { meals.remove_first() }
    button "Clear this meal plan" { clear meals }
    button "Planning note" -> Note
  }
}

screen Note {
  ui {
    section "A plan you can actually use" "Keep only meals that fit your week."
    label "Your meal plan began with: ${plan.request}"
    button "Back to meals" { go Back }
  }
}''';

  static String _readingApp(_AppPlan plan) => '''app "${plan.appName}" {
  start = "Library"
}

screen Library {
  state finished: 0
  state quietMode: true
  state bookDraft: ""
  state books: []
  ui {
    section "A smaller reading life" "Your list for ${plan.subject}."
    metric "Books finished" -> finished
    toggle "Keep this a quiet reading space" -> quietMode
    divider
    input "Add a book, article, or chapter" -> bookDraft
    button "Add to reading list" {
      books.append(bookDraft)
      bookDraft = ""
    }
    list books
    button "Mark next item finished" {
      books.remove_first()
      increment finished
    }
    button "Clear reading list" { clear books }
    button "Reading note" -> Note
  }
}

screen Note {
  ui {
    section "Read what matters" "Keep the list aligned with ${plan.subject}."
    label "Every item is editable, so this library can evolve with you."
    button "Back to library" { go Back }
  }
}''';

  static String _reminderApp(_AppPlan plan) => '''app "${plan.appName}" {
  start = "Reminders"
}

screen Reminders {
  state reminderText: ""
  state reminderTime: "09:00"
  state scheduled: []
  state scheduledCount: 0
  state gentleMode: true
  ui {
    section "Reminders that fit your day" "A gentle system for ${plan.subject}."
    metric "Reminders scheduled" -> scheduledCount
    toggle "Keep reminder language gentle" -> gentleMode
    divider
    input "What should Sprout remind you about?" -> reminderText
    input "Time in 24-hour format, for example 09:00" -> reminderTime
    button "Schedule this reminder" {
      scheduled.append("\${reminderText} at \${reminderTime}")
      reminder reminderText at reminderTime
      increment scheduledCount
      reminderText = ""
    }
    list scheduled
    button "Clear scheduled reminders" { clear scheduled }
    button "Reminder guide" -> Guide
  }
}

screen Guide {
  ui {
    section "A reminder you will welcome" "Choose a meaningful message and a real time."
    label "Sprout asks for notification permission only when you schedule."
    button "Back to reminders" { go Back }
  }
}''';

  static String _eventPlannerApp(_AppPlan plan) => '''app "${plan.appName}" {
  start = "Events"
}

screen Events {
  state eventName: ""
  state eventTime: "09:00"
  state events: []
  state eventCount: 0
  state includePrep: true
  ui {
    section "Make space for the important things" "Plan ${plan.subject} with a timely nudge."
    metric "Events planned" -> eventCount
    toggle "Include preparation time" -> includePrep
    divider
    input "Event or appointment" -> eventName
    input "Start time in 24-hour format" -> eventTime
    button "Add event and reminder" {
      events.append("\${eventName} at \${eventTime}")
      reminder eventName at eventTime
      increment eventCount
      eventName = ""
    }
    list events
    button "Clear upcoming events" { clear events }
    button "Planning guide" -> Guide
  }
}

screen Guide {
  ui {
    section "A thoughtful event plan" "Keep what supports ${plan.subject}."
    label "Each planned event stays editable and creates a local reminder."
    button "Back to events" { go Back }
  }
}''';

  static String _workspaceApp(_AppPlan plan) => '''app "${plan.appName}" {
  start = "Home"
}

screen Home {
  state itemsCreated: 0
  state keepItSimple: true
  state draft: ""
  state items: []
  ui {
    section "A workspace for your idea" "Built from your request: ${plan.subject}."
    metric "Ideas captured" -> itemsCreated
    toggle "Keep this workspace focused" -> keepItSimple
    divider
    input "Add the next useful thing" -> draft
    button "Save to workspace" {
      items.append(draft)
      increment itemsCreated
      draft = ""
    }
    list items
    button "Clear this workspace" { clear items }
    button "Open your guide" -> Guide
  }
}

screen Guide {
  ui {
    section "Make the app your own" "This is a working starting point, not a mock-up."
    label "You asked for: ${plan.request}"
    label "Edit the source to rename screens, add actions, or refine the flow."
    button "Back to workspace" { go Back }
  }
}''';
}

class _AppPlan {
  final String request;
  final String subject;
  final String appName;

  const _AppPlan({
    required this.request,
    required this.subject,
    required this.appName,
  });

  factory _AppPlan.fromRequest(String request, _AppCategory category) {
    final words = request
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toList();
    final subject = words.take(6).join(' ').trim();
    final title = words
        .take(4)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
    final suffix = switch (category) {
      _AppCategory.reminders => 'Reminders',
      _AppCategory.eventPlanner => 'Plan',
      _AppCategory.focus => 'Focus',
      _AppCategory.wellness => 'Check In',
      _AppCategory.budget => 'Budget',
      _AppCategory.meals => 'Kitchen',
      _AppCategory.reading => 'Library',
      _AppCategory.todo => 'Priorities',
      _AppCategory.shopping => 'Shopping',
      _AppCategory.notes => 'Notes',
      _AppCategory.habit => 'Routine',
      _AppCategory.navigation || _AppCategory.general => 'Workspace',
    };
    return _AppPlan(
      request: request,
      subject: subject.isEmpty ? 'your personal goals' : subject,
      appName: title.isEmpty ? 'My $suffix' : '$title $suffix',
    );
  }
}

enum _AppCategory {
  reminders,
  eventPlanner,
  focus,
  wellness,
  budget,
  meals,
  reading,
  todo,
  shopping,
  notes,
  habit,
  navigation,
  general,
}
