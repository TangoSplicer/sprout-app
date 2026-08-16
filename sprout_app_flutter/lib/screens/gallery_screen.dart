import 'package:flutter/material.dart';

import '../services/project_service.dart';
import '../services/sprout_language_catalog.dart';
import '../theme/sprout_theme.dart';
import 'editor_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _searchQuery = '';

  List<SproutLanguagePattern> get _filteredPatterns {
    if (_searchQuery.trim().isEmpty) return SproutLanguageCatalog.patterns;
    final query = _searchQuery.toLowerCase();
    return SproutLanguageCatalog.patterns.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _importPattern(SproutLanguagePattern pattern) async {
    final controller = TextEditingController(text: pattern.name);
    final projectName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adopt "${pattern.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose a name for your new app copy:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'App name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create app'),
          ),
        ],
      ),
    );

    if (projectName == null || projectName.isEmpty || !mounted) return;

    try {
      final projects = ProjectService();
      await projects.createProject(projectName);
      final code = pattern.source.replaceAll('{{appName}}', projectName);
      await projects.writeFile(projectName, 'main.sprout', code);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EditorScreen(projectName: projectName),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create app: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sprout App Gallery')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search community apps and patterns…',
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _filteredPatterns.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final pattern = _filteredPatterns[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: SproutTheme.peach,
                            child: Icon(pattern.icon, color: SproutTheme.forest, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pattern.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(pattern.description),
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  onPressed: () => _importPattern(pattern),
                                  icon: const Icon(Icons.add_circle_outline, size: 18),
                                  label: const Text('Adopt into my garden'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
