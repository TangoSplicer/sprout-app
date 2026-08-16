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

data Transaction {
  kind: String
  label: String
  amount: Number
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
  state entrySearch: ""
  state entryFilter: "All"
  ui {
    section "Every money movement" "Search, filter, correct, or remove entries whenever your plan changes."
    choice "Show category" ["All", "Income", "Outgoings", "Debt", "Savings"] -> entryFilter
    records transactions [kind, label, amount] search entrySearch filter entryFilter editable
    breakdown "January commitments" transactions amount ["Outgoings · January", "Debt · January", "Savings · January"]
    breakdown "February commitments" transactions amount ["Outgoings · February", "Debt · February", "Savings · February"]
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
    SproutLanguagePattern(
      name: 'Expense tracker',
      description:
          'Log everyday spending with editable categories, a live search, filters, and a local category breakdown.',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF9B5A2E),
      source: '''app "{{appName}}" {
  start = "Overview"
}

screen Overview {
  state expenses: []
  ui {
    section "Spend with clarity" "Every entry stays editable, searchable, and on this device."
    aggregate "This period" expenses amount ["Essential", "Flexible", "Subscription"] - ["Income"]
    breakdown "Where your money went" expenses amount ["Essential", "Flexible", "Subscription"]
    button "Add an expense" -> AddExpense
    button "Review expenses" -> Expenses
    button "How this works" -> Guide
  }
}

screen AddExpense {
  state kind: "Essential"
  state label: ""
  state amount: 0
  ui {
    section "Add an expense" "Use a specific label, such as Mobile plan or Groceries."
    choice "Category" ["Essential", "Flexible", "Subscription"] -> kind
    input "What was it for?" -> label
    number "Amount" -> amount
    button "Save expense" {
      expenses.add(kind: kind, label: label, amount: amount)
      label = ""
      amount = 0
      go Expenses
    }
    button "Cancel" { go Back }
  }
}

screen Expenses {
  state expenseSearch: ""
  state expenseFilter: "All"
  ui {
    section "Your expense history" "Find an entry, filter a category, or amend an earlier record."
    choice "Show category" ["All", "Essential", "Flexible", "Subscription"] -> expenseFilter
    records expenses [kind, label, amount] search expenseSearch filter expenseFilter editable
    button "Add another expense" -> AddExpense
    button "Back to overview" { go Back }
  }
}

screen Guide {
  ui {
    section "Use the details" "Tap the pencil beside an entry to correct it, or remove it with the bin."
    button "Back to overview" { go Back }
  }
}''',
    ),
    SproutLanguagePattern(
      name: 'Inventory tracker',
      description:
          'Maintain local stock records with quantity totals, category breakdowns, and searchable correction tools.',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF4169A8),
      source: '''app "{{appName}}" {
  start = "Stock"
}

screen Stock {
  state items: []
  ui {
    section "Know what you have" "A practical stock list for supplies, equipment, or household essentials."
    aggregate "Tracked units" items quantity ["Supplies", "Equipment", "Consumables"] - ["Removed"]
    breakdown "Units by category" items quantity ["Supplies", "Equipment", "Consumables"]
    button "Add stock" -> AddItem
    button "Browse stock" -> ItemList
  }
}

screen AddItem {
  state category: "Supplies"
  state name: ""
  state quantity: 1
  ui {
    section "Add an item" "Record a name and the number currently available."
    choice "Category" ["Supplies", "Equipment", "Consumables"] -> category
    input "Item name" -> name
    number "Quantity" -> quantity
    button "Save stock" {
      items.add(kind: category, name: name, quantity: quantity)
      name = ""
      quantity = 1
      go ItemList
    }
    button "Back to stock" { go Back }
  }
}

screen ItemList {
  state itemSearch: ""
  state categoryFilter: "All"
  ui {
    section "Your stock records" "Search by name, filter a category, or update a count in place."
    choice "Show category" ["All", "Supplies", "Equipment", "Consumables"] -> categoryFilter
    records items [kind, name, quantity] search itemSearch filter categoryFilter editable
    button "Add another item" -> AddItem
    button "Back to stock" { go Back }
  }
}''',
    ),
    SproutLanguagePattern(
      name: 'Health log',
      description:
          'Keep an editable private log of readings, wellbeing notes, and repeatable health observations.',
      icon: Icons.monitor_heart_outlined,
      color: Color(0xFFB04772),
      source: '''app "{{appName}}" {
  start = "Today"
}

screen Today {
  state observations: []
  ui {
    section "Notice your patterns" "A neutral personal log for observations you choose to keep."
    breakdown "Logged observations" observations value ["Sleep", "Mood", "Energy"]
    button "Log an observation" -> AddObservation
    button "Review history" -> History
  }
}

screen AddObservation {
  state kind: "Sleep"
  state date: ""
  state value: 0
  state notes: ""
  ui {
    section "Add a check-in" "Enter a date, a simple value, and any context that is useful to you."
    choice "What are you tracking?" ["Sleep", "Mood", "Energy"] -> kind
    input "Date or period" -> date
    number "Value" -> value
    textarea "Notes (optional)" -> notes
    button "Save check-in" {
      observations.add(kind: kind, date: date, value: value, notes: notes)
      notes = ""
      go History
    }
    button "Back to today" { go Back }
  }
}

screen History {
  state healthSearch: ""
  state healthFilter: "All"
  ui {
    section "Your private history" "Search, filter, edit, or delete a previous observation."
    choice "Show type" ["All", "Sleep", "Mood", "Energy"] -> healthFilter
    records observations [kind, date, value, notes] search healthSearch filter healthFilter editable
    button "Add another check-in" -> AddObservation
    button "Back to today" { go Back }
  }
}''',
    ),
    SproutLanguagePattern(
      name: 'Contact organiser',
      description:
          'Create a focused local relationship list with searchable details, segments, and editable notes.',
      icon: Icons.people_alt_outlined,
      color: Color(0xFF5A6F2D),
      source: '''app "{{appName}}" {
  start = "Contacts"
}

screen Contacts {
  state people: []
  ui {
    section "Keep the right details close" "A lightweight, private list for people and useful follow-up context."
    button "Add a contact" -> AddContact
    button "Browse contacts" -> Directory
  }
}

screen AddContact {
  state segment: "Personal"
  state name: ""
  state phone: ""
  state notes: ""
  ui {
    section "Add a contact" "Capture only the details that will help you next time."
    choice "Relationship" ["Personal", "Work", "Service"] -> segment
    input "Name" -> name
    input "Phone or email" -> phone
    textarea "Helpful notes" -> notes
    button "Save contact" {
      people.add(kind: segment, name: name, phone: phone, notes: notes)
      name = ""
      phone = ""
      notes = ""
      go Directory
    }
    button "Back to contacts" { go Back }
  }
}

screen Directory {
  state contactSearch: ""
  state segmentFilter: "All"
  ui {
    section "Your contact directory" "Search details, focus on a segment, or edit a contact without rebuilding the list."
    choice "Show relationship" ["All", "Personal", "Work", "Service"] -> segmentFilter
    records people [kind, name, phone, notes] search contactSearch filter segmentFilter editable
    button "Add another contact" -> AddContact
    button "Back to contacts" { go Back }
  }
}''',
    ),
    SproutLanguagePattern(
      name: 'Shared grocery list',
      description:
          'Collaborate on a household list with P2P sync and native alerts when items are added.',
      icon: Icons.shopping_basket_outlined,
      color: Color(0xFF2C5D82),
      source: '''app "{{appName}}" {
  start = "List"
}

screen List {
  state items: []
  state newItem: ""
  ui {
    section "Household List" "Sync with others on your network to stay updated."
    input "What do we need?" -> newItem
    button "Add to list" {
      items.append(newItem)
      notify "New item added: \${newItem}"
      newItem = ""
    }
    list items
    button "Sync with peers" { sync items }
    button "Clear list" { clear items }
  }
}''',
    ),
    SproutLanguagePattern(
      name: 'Smart weather hub',
      description:
          'Fetch live weather data from a public API and visualize temperature trends with interactive charts.',
      icon: Icons.wb_sunny_outlined,
      color: Color(0xFF147A4A),
      source: '''app "{{appName}}" {
  start = "Weather"
}

screen Weather {
  state city: "London"
  state weatherData: "No data"
  state history: []
  ui {
    section "Weather Insights" "Fetch live data and track local trends."
    input "Enter city" -> city
    button "Fetch current weather" {
      fetch "https://api.example.com/weather/\${city}" -> weatherData
      notify "Weather updated for \${city}"
    }
    label "Current: \${weatherData}"
    chart "Temperature Trend" history value by bar
    button "Add to history" {
      history.add(label: city, value: 20)
    }
    audio "Local Forecast" -> "https://example.com/audio/forecast.mp3"
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
      title: 'Searchable record manager',
      description:
          'Render records with a local search field, a choice filter, and in-place edit and delete controls.',
      source:
          'records transactions [kind, label, amount] search transactionSearch filter transactionFilter editable',
    ),
    SproutLanguageSnippet(
      title: 'Category breakdown',
      description:
          'Show a calculated subtotal for each selected record category.',
      source:
          'breakdown "Spending by category" transactions amount ["Essential", "Flexible", "Subscription"]',
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
