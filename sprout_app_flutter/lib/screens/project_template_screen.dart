// flutter/lib/screens/project_template_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/enhanced_ai_assistant.dart';
import 'editor_screen.dart';

class ProjectTemplate {
  final String name;
  final String description;
  final String code;
  final IconData icon;
  final Color color;

  ProjectTemplate({
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
  final TextEditingController _nameController = TextEditingController(text: 'My App');
  final List<ProjectTemplate> _templates = [];
  int _selectedTemplateIndex = 0;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    // Convert AI templates to project templates
    final aiAssistant = EnhancedAIAssistant();
    final aiTemplates = aiAssistant.getTemplates();
    
    // Define template colors and icons
    final colors = [
      const Color(0xFF4A9D5E), // Green
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFFF44336), // Red
      const Color(0xFF009688), // Teal
      const Color(0xFFFF9800), // Orange
    ];
    
    final icons = [
      Icons.check_box_outlined,
      Icons.calculate_outlined,
      Icons.note_outlined,
      Icons.favorite_outline,
      Icons.calendar_today_outlined,
    ];
    
    // Create project templates from AI templates
    for (var i = 0; i < aiTemplates.length; i++) {
      final template = aiTemplates[i];
      _templates.add(
        ProjectTemplate(
          name: template.name,
          description: template.description,
          code: template.code.replaceAll('{{title}}', _nameController.text)
              .replaceAll('{{appName}}', _nameController.text),
          icon: icons[i % icons.length],
          color: colors[i % colors.length],
        ),
      );
    }
    
    // Add blank template
    _templates.add(
      ProjectTemplate(
        name: 'Blank Project',
        description: 'Start with a clean slate',
        code: '''app "${_nameController.text}" {
  start = Home
}

screen Home {
  ui {
    column {
      title("Welcome to ${_nameController.text}")
      label("Start building your app here")
    }
  }
}''',
        icon: Icons.add_circle_outline,
        color: Colors.grey.shade700,
      ),
    );
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Project'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project name input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                hintText: 'Enter a name for your project',
              ),
              onChanged: (value) {
                // Update template code with new name
                setState(() {
                  for (var i = 0; i < _templates.length; i++) {
                    final template = _templates[i];
                    if (template.name == 'Blank Project') {
                      _templates[i] = ProjectTemplate(
                        name: template.name,
                        description: template.description,
                        code: '''app "$value" {
  start = Home
}

screen Home {
  ui {
    column {
      title("Welcome to $value")
      label("Start building your app here")
    }
  }
}''',
                        icon: template.icon,
                        color: template.color,
                      );
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Choose a template:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Template grid
            Expanded(
              child: _templates.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final template = _templates[index];
                      final isSelected = _selectedTemplateIndex == index;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTemplateIndex = index;
                          });
                        },
                        child: Card(
                          elevation: isSelected ? 4 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isSelected
                              ? BorderSide(color: template.color, width: 2)
                              : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  template.icon,
                                  size: 48,
                                  color: template.color,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  template.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
            
            const SizedBox(height: 16),
            
            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.create),
                label: Text(_isCreating ? 'Creating...' : 'Create Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isCreating ? null : _createProject,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createProject() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a project name')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final projectName = _nameController.text.trim();
      final template = _templates[_selectedTemplateIndex];
      
      // Create the project
      await appState.createProject(projectName);
      
      // Save the template code
      await appState.saveCode(template.code.replaceAll('{{title}}', projectName)
          .replaceAll('{{appName}}', projectName));
      
      if (mounted) {
        // Navigate to the editor
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EditorScreen(projectName: projectName),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating project: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}