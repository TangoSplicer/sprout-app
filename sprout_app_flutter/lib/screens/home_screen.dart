import 'package:flutter/material.dart';

import '../services/project_service.dart';
import '../theme/sprout_theme.dart';
import 'editor_screen.dart';
import 'learning_screen.dart';
import 'project_template_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<String>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    ProjectService().projectChanges.addListener(_refreshProjects);
    _projectsFuture = ProjectService().loadProjectNames();
  }

  @override
  void dispose() {
    ProjectService().projectChanges.removeListener(_refreshProjects);
    super.dispose();
  }

  void _refreshProjects() {
    if (!mounted) return;
    setState(() => _projectsFuture = ProjectService().loadProjectNames());
  }

  Future<void> _openTemplates() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProjectTemplateScreen()),
    );
    if (mounted) _refreshProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: SproutTheme.sage,
              child: Icon(Icons.spa_outlined, color: SproutTheme.forest),
            ),
            SizedBox(width: 10),
            Text('Sprout'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.school_outlined),
            tooltip: 'Learn how Sprout works',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LearningScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Open settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: SproutTheme.peach,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Make one small thing useful.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: SproutTheme.ink,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start from a simple template or describe what you need. You can always inspect, edit, and preview the result.',
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _openTemplates,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Create an app'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LearningScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Learn in 5 minutes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your projects',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Open one to keep shaping it, or make a new starting point.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _projectsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const _MessageCard(
                      icon: Icons.cloud_off_outlined,
                      title: 'Your projects could not be loaded',
                      body: 'Try returning here after checking storage access.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final projects = snapshot.data!;
                  if (projects.isEmpty) return const _EmptyState();
                  return ListView.separated(
                    itemCount: projects.length,
                    padding: const EdgeInsets.only(bottom: 12),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: SproutTheme.sage,
                            child: Icon(Icons.auto_stories_outlined,
                                color: SproutTheme.forest),
                          ),
                          title: Text(project,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle:
                              const Text('Open, edit, and preview this app'),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded,
                              size: 18),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditorScreen(projectName: project),
                            ),
                          ).then((_) => _refreshProjects()),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: _openTemplates,
            icon: const Icon(Icons.add),
            label: const Text('Create a new app'),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      icon: Icons.spa_outlined,
      title: 'Your garden is ready',
      body:
          'Create your first small app above. A template is a good place to begin.',
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: SproutTheme.clay),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
