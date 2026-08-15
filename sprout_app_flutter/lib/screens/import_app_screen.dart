import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/sprout_app_package.dart';
import '../theme/sprout_theme.dart';

class ImportAppScreen extends StatefulWidget {
  final File? initialFile;

  const ImportAppScreen({super.key, this.initialFile});

  @override
  State<ImportAppScreen> createState() => _ImportAppScreenState();
}

class _ImportAppScreenState extends State<ImportAppScreen> {
  final SproutAppPackageService _packages = SproutAppPackageService();
  final TextEditingController _nameController = TextEditingController();
  File? _file;
  SproutPackagePreview? _preview;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final initialFile = widget.initialFile;
    if (initialFile != null) _inspect(initialFile);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['sproutapp'],
      withData: false,
    );
    final path = result?.files.singleOrNull?.path;
    if (path != null) await _inspect(File(path));
  }

  Future<void> _inspect(File file) async {
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final preview = _packages.inspectFile(file);
      if (!mounted) return;
      setState(() {
        _file = file;
        _preview = preview;
        _nameController.text = preview.manifest.projectName;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final file = _file;
    if (file == null) return;
    setState(() => _loading = true);
    try {
      final imported = await _packages.importFile(
        file,
        preferredName: _nameController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, imported.projectName);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Add a shared app')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: SproutTheme.peach,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.move_to_inbox_outlined, color: SproutTheme.forest),
                  SizedBox(height: 10),
                  Text(
                    'Bring an app into your garden',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Choose a .sproutapp file shared from another Sprout device. You can inspect its details before creating your own local copy.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loading ? null : _chooseFile,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Choose a Sprout app package'),
            ),
            if (_loading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_error != null) ...[
              const SizedBox(height: 20),
              _NoticeCard(
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                message: _error!,
              ),
            ],
            if (preview != null) ...[
              const SizedBox(height: 24),
              Text('Package preview',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.manifest.projectName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        icon: Icons.description_outlined,
                        label: 'Source',
                        value: '${preview.source.split('\n').length} lines',
                      ),
                      _DetailRow(
                        icon: preview.manifest.includesAppState
                            ? Icons.data_object_outlined
                            : Icons.lock_outline,
                        label: 'Shared data',
                        value: preview.manifest.includesAppState
                            ? 'Included by the sender'
                            : 'Not included',
                      ),
                      const _DetailRow(
                        icon: Icons.verified_user_outlined,
                        label: 'Package check',
                        value: 'Source integrity verified',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Save your copy as',
                  helperText:
                      'A number is added automatically if the name is already used.',
                ),
              ),
              const SizedBox(height: 8),
              _NoticeCard(
                icon: Icons.privacy_tip_outlined,
                color: Theme.of(context).colorScheme.primary,
                message: preview.manifest.includesAppState
                    ? 'This package includes the sender’s local app data. Import only information you are comfortable keeping on this device.'
                    : 'This package contains the app design only. Your copy starts with its own empty local data.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loading ? null : _import,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add this app to Sprout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
