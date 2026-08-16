import 'dart:io';

import 'package:flutter/material.dart';

import '../services/native_bridge.dart';
import '../services/project_service.dart';
import '../theme/sprout_theme.dart';
import 'editor_screen.dart';
import 'gallery_screen.dart';
import 'import_app_screen.dart';
import 'learning_screen.dart';
import 'preview_screen.dart';
import 'project_template_screen.dart';
import 'settings_screen.dart';
import 'share_screen.dart';

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
    NativeBridge.setPlatformLaunchHandlers(
      onIncomingPackage: _handleIncomingPackage,
      onProxyLaunch: _openProxyProject,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingPlatformActions();
    });
  }

  @override
  void dispose() {
    ProjectService().projectChanges.removeListener(_refreshProjects);
    NativeBridge.setPlatformLaunchHandlers();
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

  Future<void> _openImport({File? initialFile}) async {
    final importedName = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportAppScreen(initialFile: initialFile),
      ),
    );
    if (!mounted) return;
    if (importedName != null) {
      _refreshProjects();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$importedName was added to your projects.')),
      );
    }
  }

  Future<void> _handleIncomingPackage(String packagePath) async {
    if (!mounted) return;
    await _openImport(initialFile: File(packagePath));
  }

  Future<void> _openProxyProject(String projectName) async {
    await _runProject(
      projectName,
      missingMessage: 'This home-screen app is no longer available in Sprout.',
    );
  }

  Future<void> _runProject(
    String projectName, {
    String missingMessage = 'This app is no longer available in Sprout.',
  }) async {
    final projects = await ProjectService().loadProjectNames();
    if (!mounted) return;
    if (!projects.contains(projectName)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(missingMessage)));
      return;
    }
    try {
      final source =
          await ProjectService().readFile(projectName, 'main.sprout');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(code: source, projectName: projectName),
        ),
      );
      if (mounted) _refreshProjects();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This app could not be opened right now.')),
      );
    }
  }

  Future<void> _handleProjectAction(
    _ProjectAction action,
    String projectName,
  ) async {
    switch (action) {
      case _ProjectAction.run:
        await _runProject(projectName);
        return;
      case _ProjectAction.share:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ShareScreen(projectName: projectName)),
        );
        return;
      case _ProjectAction.addToHome:
        try {
          final requested = await NativeBridge.requestAppShortcut(projectName);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                requested
                    ? 'Android will now offer $projectName as a home-screen app.'
                    : 'Your launcher does not support adding this app to the home screen.',
              ),
            ),
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Home-screen apps need a supported Android launcher.'),
              ),
            );
          }
        }
        return;
    }
  }

  Future<void> _consumePendingPlatformActions() async {
    try {
      final packagePath = await NativeBridge.consumeIncomingAppPackage();
      if (packagePath != null && mounted) {
        await _handleIncomingPackage(packagePath);
      }
      final projectName = await NativeBridge.consumeLaunchProject();
      if (projectName != null && mounted) {
        await _openProxyProject(projectName);
      }
    } catch (_) {
      // Desktop, browser, and widget-test targets have no Android bridge.
    }
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh projects',
            onPressed: _refreshProjects,
          ),
          IconButton(
            icon: const Icon(Icons.move_to_inbox_outlined),
            tooltip: 'Add a shared app',
            onPressed: () => _openImport(),
          ),
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
                        onPressed: () => _openImport(),
                        icon: const Icon(Icons.move_to_inbox_outlined),
                        label: const Text('Add a shared app'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GalleryScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text('Explore gallery'),
                      ),
                      TextButton.icon(
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
                          trailing: PopupMenuButton<_ProjectAction>(
                            tooltip: 'App actions',
                            onSelected: (action) =>
                                _handleProjectAction(action, project),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: _ProjectAction.run,
                                child: ListTile(
                                  leading: Icon(Icons.play_arrow_rounded),
                                  title: Text('Run app'),
                                ),
                              ),
                              PopupMenuItem(
                                value: _ProjectAction.share,
                                child: ListTile(
                                  leading: Icon(Icons.ios_share_outlined),
                                  title: Text('Share app'),
                                ),
                              ),
                              PopupMenuItem(
                                value: _ProjectAction.addToHome,
                                child: ListTile(
                                  leading:
                                      Icon(Icons.add_to_home_screen_outlined),
                                  title: Text('Add to home screen'),
                                ),
                              ),
                            ],
                          ),
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

enum _ProjectAction { run, share, addToHome }

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
