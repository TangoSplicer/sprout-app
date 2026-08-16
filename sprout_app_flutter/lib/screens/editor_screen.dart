import 'package:flutter/material.dart';

import '../services/debugger.dart';
import '../services/language_server.dart';
import '../services/native_bridge.dart';
import '../services/project_service.dart';
import '../widgets/debug_console.dart';
import '../widgets/syntax_editor.dart';
import 'language_tools_screen.dart';
import 'preview_screen.dart';
import '../services/sprout_cloud_service.dart';
import 'share_screen.dart';
import 'version_history_screen.dart';
import 'visual_editor_screen.dart';

class EditorScreen extends StatefulWidget {
  final String projectName;

  const EditorScreen({super.key, required this.projectName});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Future<String> _codeFuture;
  TextEditingController? _controller;
  bool _showConsole = false;
  final SproutDebugger _debugger = SproutDebugger();
  final LanguageServerClient _ls = LanguageServerClient();
  String? _aiFeedback;

  @override
  void initState() {
    super.initState();
    _codeFuture = ProjectService().readFile(widget.projectName, 'main.sprout');
    _codeFuture.then((content) {
      if (!mounted) return;
      setState(() {
        _controller = TextEditingController(text: content);
      });
      _ls.notifyChange(content);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<bool> _compile({bool announce = true}) async {
    final controller = _controller;
    if (controller == null) return false;
    _debugger.clear();

    try {
      final output = await ProjectService().compileCode(controller.text);
      if (output.isEmpty) {
        throw StateError('The compiler returned no preview output.');
      }
      _debugger.log('App compiled successfully.');
      if (announce && mounted) {
        _showMessage('Your app is ready to preview.');
      }
      return true;
    } catch (error, stack) {
      _debugger.error('Compile error: $error', stack: stack);
      if (mounted) {
        setState(() => _showConsole = true);
        _showMessage('Fix the highlighted compile issue, then try again.',
            error: true);
      }
      return false;
    }
  }

  Future<bool> _save({bool announce = true}) async {
    final controller = _controller;
    if (controller == null) return false;
    try {
      await ProjectService()
          .writeFile(widget.projectName, 'main.sprout', controller.text);
      await _ls.notifyChange(controller.text);
      _debugger.log('Saved to project.');
      if (announce && mounted) _showMessage('Saved to ${widget.projectName}.');
      return true;
    } catch (error, stack) {
      _debugger.error('Save failed: $error', stack: stack);
      if (mounted) _showMessage('Could not save this project.', error: true);
      return false;
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _addToHomeScreen() async {
    final saved = await _save(announce: false);
    if (!saved || !mounted) return;
    try {
      final requested =
          await NativeBridge.requestAppShortcut(widget.projectName);
      if (!mounted) return;
      _showMessage(
        requested
            ? 'Android will now offer ${widget.projectName} as a home-screen app.'
            : 'Your launcher does not support adding this Sprout app to the home screen.',
        error: !requested,
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
            'Home-screen apps are available on a supported Android launcher.',
            error: true);
      }
    }
  }

  Future<void> _cloudBackup() async {
    final saved = await _save(announce: false);
    if (!saved || !mounted) return;

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encrypted Cloud Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Create a secure, zero-knowledge backup of this app and its data.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Passphrase',
                hintText: 'Enter a strong passphrase',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Backup')),
        ],
      ),
    );

    if (confirmed == true && controller.text.isNotEmpty) {
      try {
        final backup = await SproutCloudService()
            .createEncryptedBackup(widget.projectName, controller.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Encrypted backup created: ${backup.path}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Backup failed: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.projectName),
            Text(
              'Edit your app',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showConsole ? Icons.terminal : Icons.terminal_outlined),
            tooltip: _showConsole ? 'Hide activity log' : 'Show activity log',
            onPressed: () => setState(() => _showConsole = !_showConsole),
          ),
          IconButton(
            icon: const Icon(Icons.add_to_home_screen_outlined),
            tooltip: 'Add this app to your home screen',
            onPressed: _addToHomeScreen,
          ),
          IconButton(
            icon: const Icon(Icons.widgets_outlined),
            tooltip: 'Visual builder',
            onPressed: () async {
              final controller = _controller;
              if (controller == null) return;
              final newCode = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => VisualEditorScreen(
                    projectName: widget.projectName,
                    initialSource: controller.text,
                  ),
                ),
              );
              if (newCode != null && mounted) {
                controller.text = newCode;
                await _save(announce: false);
                setState(() {});
                _showMessage('Visual changes applied to app source.');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Version history',
            onPressed: () async {
              final restored = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => VersionHistoryScreen(projectName: widget.projectName),
                ),
              );
              if (restored == true && mounted) {
                _codeFuture = ProjectService().readFile(widget.projectName, 'main.sprout');
                final content = await _codeFuture;
                if (!mounted) return;
                setState(() {
                  _controller = TextEditingController(text: content);
                });
                _showMessage('Restored project version.');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Cloud backup',
            onPressed: _cloudBackup,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share this project',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShareScreen(projectName: widget.projectName),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _codeFuture,
        builder: (context, snapshot) {
          if (controller == null || !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  'Write or ask for an app. Save it, then preview exactly what people will use.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(
                flex: _showConsole ? 3 : 1,
                child: SyntaxEditor(
                  text: controller.text,
                  onChanged: (text) async {
                    controller.value = TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                    await _ls.notifyChange(text);
                  },
                ),
              ),
              if (_showConsole)
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      Expanded(
                        child: DebugConsole(
                          logs: _debugger.logs
                              .map((entry) => entry.message)
                              .toList(),
                          errors: _debugger.errors
                              .map((entry) => entry.message)
                              .toList(),
                          aiFeedback: _aiFeedback,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).bottomAppBarTheme.color,
        elevation: Theme.of(context).bottomAppBarTheme.elevation ?? 0,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final previewCode = controller?.text;
                          if (previewCode == null) return;
                          final saved = await _save(announce: false);
                          final compiled =
                              saved && await _compile(announce: false);
                          if (!mounted || !compiled) return;
                          await navigator.push(
                            MaterialPageRoute(
                              builder: (_) => PreviewScreen(
                                code: previewCode,
                                projectName: widget.projectName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Preview'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final currentCode = controller?.text;
                          if (currentCode == null) return;
                          final result = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LanguageToolsScreen(
                                projectName: widget.projectName,
                                source: currentCode,
                              ),
                            ),
                          );
                          if (result != null) await _applyReviewedCode(result);
                        },
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Review source'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ShareScreen(projectName: widget.projectName),
                          ),
                        ),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyReviewedCode(String code) async {
    final controller = _controller;
    if (controller == null) return;
    controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    final saved = await _save(announce: false);
    if (!mounted) return;
    if (saved) {
      setState(
          () => _aiFeedback = 'Your reviewed source was applied and saved.');
      _showMessage(
          'Your reviewed source is active. Preview it when you are ready.');
    }
  }
}
