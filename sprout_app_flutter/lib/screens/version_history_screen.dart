import 'package:flutter/material.dart';

import '../services/project_service.dart';
import '../theme/sprout_theme.dart';

class VersionHistoryScreen extends StatefulWidget {
  final String projectName;

  const VersionHistoryScreen({super.key, required this.projectName});

  @override
  State<VersionHistoryScreen> createState() => _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends State<VersionHistoryScreen> {
  late Future<List<ProjectVersion>> _versionsFuture;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  void _loadVersions() {
    setState(() {
      _versionsFuture = ProjectService().listVersions(widget.projectName);
    });
  }

  Future<void> _restore(ProjectVersion version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this version?'),
        content: Text('Restore project state from ${version.date.toLocal()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ProjectService().restoreVersion(widget.projectName, version.timestamp);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not restore version: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Version History & Restore Points')),
      body: SafeArea(
        child: FutureBuilder<List<ProjectVersion>>(
          future: _versionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading history: ${snapshot.error}'));
            }
            final versions = snapshot.data ?? [];
            if (versions.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_outlined, size: 48, color: SproutTheme.forest),
                      SizedBox(height: 16),
                      Text(
                        'No previous versions yet',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Sprout automatically saves restore points whenever you save changes to your app.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: versions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final v = versions[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: SproutTheme.sage,
                      child: Icon(Icons.restore_rounded, color: SproutTheme.forest),
                    ),
                    title: Text('Restore point #${versions.length - index}'),
                    subtitle: Text('${v.date.toLocal()}'),
                    trailing: FilledButton.tonal(
                      onPressed: () => _restore(v),
                      child: const Text('Restore'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
