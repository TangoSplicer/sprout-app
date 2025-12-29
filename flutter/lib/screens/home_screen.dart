// flutter/lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'editor_screen.dart';

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
    _projectsFuture = ProjectService().loadProjectNames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco, color: Color(0xFF4A9D5E)),
            SizedBox(width: 8),
            Text(
              'Sprout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A9D5E),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your Apps',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _projectsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final projects = snapshot.data!;
                    if (projects.isEmpty) {
                      return const _EmptyState();
                    }
                    return ListView.builder(
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final name = projects[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.code, color: Color(0xFF4A9D5E)),
                            title: Text(name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditorScreen(projectName: name),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A9D5E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New App'),
                onPressed: () => _createNewApp(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createNewApp(BuildContext context) async {
    final controller = TextEditingController(text: 'My App');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New App'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'App Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A9D5E)),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      await ProjectService().createProject(result);
      setState(() {
        _projectsFuture = ProjectService().loadProjectNames();
      });
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.light_mode, size: 64, color: Color(0xFFFFC107)),
          const SizedBox(height: 16),
          const Text(
            'No apps yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Tap "+" to grow your first one.'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}