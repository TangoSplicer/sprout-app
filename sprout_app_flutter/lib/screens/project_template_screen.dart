import 'package:flutter/material.dart';

import '../services/project_service.dart';
import 'ai_screen.dart';
import 'editor_screen.dart';

class ProjectTemplate {
  final String name;
  final String description;
  final String code;
  final IconData icon;
  final Color color;

  const ProjectTemplate({
    required this.name,
    required this.description,
    required this.code,
    required this.icon,
    required this.color,
  });
}

class ProjectTemplateScreen extends StatefulWidget {
  const ProjectTemplateScreen({super.key});

  @override
  State<ProjectTemplateScreen> createState() => _ProjectTemplateScreenState();
}

class _ProjectTemplateScreenState extends State<ProjectTemplateScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'My Sprout App');
  int _selectedTemplateIndex = 0;
  bool _isCreating = false;

  static const _templates = [
    ProjectTemplate(
      name: 'Ranked Todo',
      description: 'Plan the most important tasks first.',
      icon: Icons.format_list_numbered,
      color: Color(0xFF167A4A),
      code: '''app "{{appName}}" {
  start = "Todo"
}

screen Todo {
  state draft: ""
  state tasks: []
  ui {
    label "My ranked tasks"
    label "Add what matters, then complete the top item."
    input "Task to rank" -> draft
    list tasks
    button "Add task" {
      tasks.append(draft)
      draft = ""
    }
    button "Complete top task" {
      tasks.remove_first()
    }
    button "How this works" -> Help
  }
}

screen Help {
  ui {
    label "Your newest task appears at the bottom of the list."
    button "Back to tasks" { go Back }
  }
}''',
    ),
    ProjectTemplate(
      name: 'Daily Reminders',
      description: 'Schedule a local notification for one important thing.',
      icon: Icons.notifications_active_outlined,
      color: Color(0xFF4169A8),
      code: '''app "{{appName}}" {
  start = "Reminders"
}

screen Reminders {
  state reminderText: ""
  state reminderTime: "09:00"
  state scheduled: []
  ui {
    label "Daily reminders"
    label "Choose a message and a time in 24-hour format."
    input "What should Sprout remind you about?" -> reminderText
    input "Time, for example 09:00" -> reminderTime
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
    label "Sprout asks for notification permission only when you schedule."
    button "Back to reminders" { go Back }
  }
}''',
    ),
    ProjectTemplate(
      name: 'Quick Notes',
      description: 'Capture thoughts in one focused place.',
      icon: Icons.sticky_note_2_outlined,
      color: Color(0xFF9B5A2E),
      code: '''app "{{appName}}" {
  start = "Notes"
}

screen Notes {
  state draft: ""
  state notes: []
  ui {
    label "Quick notes"
    label "Keep the next important thought close."
    input "Write a note" -> draft
    list notes
    button "Save note" {
      notes.append(draft)
      draft = ""
    }
    button "Archive first note" {
      notes.remove_first()
    }
    button "About notes" -> Help
  }
}

screen Help {
  ui {
    label "Notes stay on this device until you choose to share them."
    button "Back to notes" { go Back }
  }
}''',
    ),
    ProjectTemplate(
      name: 'Habit Check-in',
      description: 'A calm daily check-in for one routine.',
      icon: Icons.favorite_outline,
      color: Color(0xFFB04772),
      code: '''app "{{appName}}" {
  start = "Habit"
}

screen Habit {
  state draft: ""
  state habits: []
  ui {
    label "Today’s habit"
    label "One small action is enough."
    input "Habit to practise" -> draft
    list habits
    button "Add habit" {
      habits.append(draft)
      draft = ""
    }
    button "Complete first habit" {
      habits.remove_first()
    }
    button "Habit encouragement" -> Help
  }
}

screen Help {
  ui {
    label "Return tomorrow and keep the next small action visible."
    button "Back to habits" { go Back }
  }
}''',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start with a template')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a simple starting point',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'You can adjust every label and action after it opens.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'App name',
                  hintText: 'e.g. Weekly Tasks',
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 600 ? 3 : 2;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final template = _templates[index];
                        final selected = _selectedTemplateIndex == index;
                        return Semantics(
                          selected: selected,
                          button: true,
                          label: '${template.name} template',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () =>
                                setState(() => _selectedTemplateIndex = index),
                            child: Card(
                              color: selected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(template.icon,
                                        color: template.color, size: 32),
                                    const Spacer(),
                                    Text(template.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    Text(template.description,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isCreating ? null : _createProject,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(_isCreating ? 'Creating…' : 'Create and edit'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCreating
                      ? null
                      : () => _createProject(openStudio: true),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Create with Sprout Studio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createProject({bool openStudio = false}) async {
    final projectName = _nameController.text.trim();
    if (projectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your app a name first.')),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final template = _templates[_selectedTemplateIndex];
      final code = template.code.replaceAll('{{appName}}', projectName);
      final projects = ProjectService();
      await projects.createProject(projectName);
      await projects.writeFile(projectName, 'main.sprout', code);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => openStudio
              ? AIScreen(projectName: projectName)
              : EditorScreen(projectName: projectName),
        ),
      );
    } on ProjectException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not create this app. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
