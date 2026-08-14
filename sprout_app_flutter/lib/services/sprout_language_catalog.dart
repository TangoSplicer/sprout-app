import 'package:flutter/material.dart';

/// The local, deterministic building blocks of Sprout.
///
/// Patterns in this catalog are complete, editable SproutScript documents. They
/// are designed to be useful without a model, and share the same bounded grammar
/// that the Rust compiler and interactive preview validate.
class SproutLanguageCatalog {
  const SproutLanguageCatalog._();

  static const patterns = <SproutLanguagePattern>[
    SproutLanguagePattern(
      name: 'Goal tracker',
      description:
          'Track meaningful progress with a clear target and check-ins.',
      icon: Icons.flag_outlined,
      color: Color(0xFF147A4A),
      source: '''app "{{appName}}" {
  start = "Today"
}

screen Today {
  state progress: 0
  state target: 7
  state focus: ""
  state reflection: ""
  state calmMode: true
  ui {
    section "Move one goal forward" "A small plan that stays connected to what matters."
    progress "This week" progress / target
    metric "Check-ins" -> progress
    toggle "Keep this plan gentle" -> calmMode
    choice "What needs your attention?" ["Start", "Continue", "Finish"] -> focus
    textarea "Write one honest next step" -> reflection
    button "Record a check-in" { increment progress }
    button "Reset this week" { progress = 0 }
    button "Why this works" -> Guide
  }
}

screen Guide {
  ui {
    section "A goal is a practice" "You can edit the target, copy, and actions whenever your life changes."
    label "Make the next step small enough to do today."
    button "Back to today" { go Back }
  }
}''',
    ),
    SproutLanguagePattern(
      name: 'Reflection journal',
      description:
          'Capture a short reflection and choose the tone of your day.',
      icon: Icons.auto_stories_outlined,
      color: Color(0xFF9B5A2E),
      source: '''app "{{appName}}" {
  start = "Journal"
}

screen Journal {
  state entry: ""
  state mood: "Steady"
  state entries: []
  state entriesSaved: 0
  ui {
    section "A private moment to reflect" "A few honest lines are enough."
    metric "Entries saved" -> entriesSaved
    choice "How does today feel?" ["Light", "Steady", "Heavy"] -> mood
    textarea "What would you like to remember?" -> entry
    button "Save this reflection" {
      entries.append("\${mood}: \${entry}")
      increment entriesSaved
      entry = ""
    }
    list entries
    button "Clear the journal" { clear entries }
    button "Journal guide" -> Guide
  }
}

screen Guide {
  ui {
    section "Your words stay yours" "This local journal is a starting point, not a verdict on your day."
    button "Back to journal" { go Back }
  }
}''',
    ),
    SproutLanguagePattern(
      name: 'Focus routine',
      description: 'Run focused sessions and gently park distractions.',
      icon: Icons.timer_outlined,
      color: Color(0xFF4169A8),
      source: '''app "{{appName}}" {
  start = "Focus"
}

screen Focus {
  state sessions: 0
  state target: 4
  state distraction: ""
  state distractions: []
  state protectFocus: true
  ui {
    section "A protected focus block" "Do less, with more intention."
    progress "Today’s focus" sessions / target
    metric "Sessions complete" -> sessions
    toggle "Protect this focus time" -> protectFocus
    input "Park a distraction for later" -> distraction
    button "Finish a focus session" { increment sessions }
    button "Park this distraction" {
      distractions.append(distraction)
      distraction = ""
    }
    list distractions
    button "Clear distractions" { clear distractions }
    button "Focus guide" -> Guide
  }
}

screen Guide {
  ui {
    section "Give your attention a home" "The list is for distractions, not another task list."
    button "Back to focus" { go Back }
  }
}''',
    ),
    SproutLanguagePattern(
      name: 'Routine builder',
      description: 'Create a repeatable, calm routine with a visible streak.',
      icon: Icons.favorite_outline,
      color: Color(0xFFB04772),
      source: '''app "{{appName}}" {
  start = "Routine"
}

screen Routine {
  state streak: 0
  state target: 5
  state habit: ""
  state habits: []
  state reminderStyle: "Gentle"
  ui {
    section "Build a routine that fits" "One small action can be a real win."
    progress "Weekly rhythm" streak / target
    metric "Check-ins" -> streak
    choice "Reminder style" ["Gentle", "Direct", "Off"] -> reminderStyle
    input "Name a small routine" -> habit
    button "Add this routine" {
      habits.append(habit)
      habit = ""
    }
    list habits
    button "Complete a check-in" { increment streak }
    button "Reset the routine" { clear habits }
    button "Routine guide" -> Guide
  }
}

screen Guide {
  ui {
    section "Consistency is flexible" "Rename, shorten, or replace any routine as needed."
    button "Back to routine" { go Back }
  }
}''',
    ),
    SproutLanguagePattern(
      name: 'Month-on-month budget',
      description:
          'Track money in, outgoings, debt, and savings across two months with automatic local balances.',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFF2C5D82),
      source: '''app "{{appName}}" {
  start = "Dashboard"
}

screen Dashboard {
  state transactions: []
  ui {
    section "Your money, made visible" "Private local planning for January and February."
    aggregate "January balance" transactions amount ["Income · January"] - ["Outgoings · January", "Debt · January", "Savings · January"]
    aggregate "February balance" transactions amount ["Income · February"] - ["Outgoings · February", "Debt · February", "Savings · February"]
    button "Add an entry" -> Entry
    button "Compare months" -> Compare
    button "View every entry" -> Entries
    button "How this planner works" -> Guide
  }
}

screen Entry {
  state kind: "Income · January"
  state label: ""
  state amount: 0
  ui {
    section "Add a money movement" "Label it clearly so your future self understands it."
    choice "What is this?" ["Income · January", "Outgoings · January", "Debt · January", "Savings · January", "Income · February", "Outgoings · February", "Debt · February", "Savings · February"] -> kind
    input "Name, for example Music subscription" -> label
    number "Amount" -> amount
    button "Save entry" {
      transactions.add(kind: kind, label: label, amount: amount)
      label = ""
      amount = 0
      go Dashboard
    }
    button "Back to dashboard" { go Back }
  }
}

screen Compare {
  ui {
    section "Month on month" "Your balances update from every entry you save."
    aggregate "January balance" transactions amount ["Income · January"] - ["Outgoings · January", "Debt · January", "Savings · January"]
    aggregate "February balance" transactions amount ["Income · February"] - ["Outgoings · February", "Debt · February", "Savings · February"]
    button "Add another entry" -> Entry
    button "Back to dashboard" { go Back }
  }
}

screen Entries {
  ui {
    section "Every money movement" "Income, subscriptions, debt payments, and savings live together in this private list."
    records transactions [kind, label, amount]
    button "Clear all entries" { clear transactions }
    button "Back to dashboard" { go Back }
  }
}

screen Guide {
  ui {
    section "Make the budget yours" "Edit categories, labels, months, or add more comparison screens directly in source."
    label "All app data stays on this device inside this project until you delete it."
    button "Back to dashboard" { go Back }
  }
}''',
    ),
    SproutLanguagePattern(
      name: 'Personal planner',
      description:
          'Capture plans, select a priority, and schedule a local nudge.',
      icon: Icons.event_note_outlined,
      color: Color(0xFF5A6F2D),
      source: '''app "{{appName}}" {
  start = "Plan"
}

screen Plan {
  state task: ""
  state time: "09:00"
  state priority: "Important"
  state plans: []
  state planned: 0
  ui {
    section "Plan what deserves a place" "A thoughtful list with a timely nudge."
    metric "Plans created" -> planned
    choice "Priority" ["Important", "Useful", "Later"] -> priority
    input "What are you planning?" -> task
    input "When should Sprout nudge you?" -> time
    button "Add plan and reminder" {
      plans.append("\${priority}: \${task} at \${time}")
      reminder task at time
      increment planned
      task = ""
    }
    list plans
    button "Clear this plan" { clear plans }
    button "Planner guide" -> Guide
  }
}

screen Guide {
  ui {
    section "Plan for a real life" "The source is yours to reshape as your needs change."
    button "Back to plan" { go Back }
  }
}''',
    ),
  ];

  static const snippets = <SproutLanguageSnippet>[
    SproutLanguageSnippet(
      title: 'Section',
      description:
          'Create a strong visual grouping with a title and supporting detail.',
      source:
          'section "What matters now" "A little context helps the screen feel intentional."',
    ),
    SproutLanguageSnippet(
      title: 'Choice',
      description: 'Offer a focused set of up to eight options.',
      source: 'choice "Priority" ["Important", "Useful", "Later"] -> priority',
    ),
    SproutLanguageSnippet(
      title: 'Reflection',
      description: 'Collect a longer, editable response.',
      source: 'textarea "Write a short reflection" -> reflection',
    ),
    SproutLanguageSnippet(
      title: 'Progress',
      description: 'Display a bounded value against a target.',
      source: 'progress "This week" progress / target',
    ),
    SproutLanguageSnippet(
      title: 'Money field',
      description:
          'Collect a local decimal amount for budgets, quantities, or rates.',
      source: 'number "Amount" -> amount',
    ),
    SproutLanguageSnippet(
      title: 'Record list',
      description: 'Render structured local entries with selected fields.',
      source: 'records transactions [kind, label, amount]',
    ),
    SproutLanguageSnippet(
      title: 'Balance total',
      description:
          'Calculate a local total using explicit positive and negative record kinds.',
      source:
          'aggregate "Monthly balance" transactions amount ["Income"] - ["Outgoings", "Debt", "Savings"]',
    ),
    SproutLanguageSnippet(
      title: 'Save record',
      description: 'Store a bounded structured entry from named form fields.',
      source:
          'button "Save entry" {\n  transactions.add(kind: kind, label: label, amount: amount)\n}',
    ),
    SproutLanguageSnippet(
      title: 'Reminder',
      description:
          'Schedule a local notification after the user enters a valid time.',
      source: 'button "Schedule reminder" {\n  reminder message at time\n}',
    ),
    SproutLanguageSnippet(
      title: 'Save to list',
      description: 'Append a user value, then clear the field.',
      source: 'button "Save" {\n  items.append(draft)\n  draft = ""\n}',
    ),
  ];
}

class SproutLanguagePattern {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String source;

  const SproutLanguagePattern({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.source,
  });
}

class SproutLanguageSnippet {
  final String title;
  final String description;
  final String source;

  const SproutLanguageSnippet({
    required this.title,
    required this.description,
    required this.source,
  });
}
