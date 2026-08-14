import 'package:flutter/material.dart';

import '../services/project_service.dart';
import '../services/sprout_language_catalog.dart';
import 'editor_screen.dart';

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

  List<SproutLanguagePattern> get _patterns => SproutLanguageCatalog.patterns;

  @override
  Widget build(BuildContext context) {
    final selected = _patterns[_selectedTemplateIndex];
    return Scaffold(
      appBar: AppBar(title: const Text('Build from a local pattern')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start with working code',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Each pattern is a complete Sprout app with real state, controls, '
                'and preview behavior. You own every line.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'App name',
                  hintText: 'e.g. My weekly focus plan',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose a functional pattern',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 680 ? 3 : 2;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: 0.78,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _patterns.length,
                      itemBuilder: (context, index) {
                        final pattern = _patterns[index];
                        final isSelected = _selectedTemplateIndex == index;
                        return Semantics(
                          selected: isSelected,
                          button: true,
                          label: '${pattern.name} pattern',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () =>
                                setState(() => _selectedTemplateIndex = index),
                            child: Card(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(pattern.icon,
                                        color: pattern.color, size: 32),
                                    const Spacer(),
                                    Text(
                                      pattern.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      pattern.description,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
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
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${selected.name}: ${selected.description}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isCreating ? null : _createProject,
                  icon: const Icon(Icons.code_rounded),
                  label: Text(
                      _isCreating ? 'Creating…' : 'Create and edit source'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createProject() async {
    final projectName = _nameController.text.trim();
    if (projectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your app a name first.')),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final pattern = _patterns[_selectedTemplateIndex];
      final code = pattern.source.replaceAll('{{appName}}', projectName);
      final projects = ProjectService();
      await projects.createProject(projectName);
      await projects.writeFile(projectName, 'main.sprout', code);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EditorScreen(projectName: projectName),
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
