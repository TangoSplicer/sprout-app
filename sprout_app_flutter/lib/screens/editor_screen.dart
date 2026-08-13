import 'package:flutter/material.dart';

import '../services/debugger.dart';
import '../services/language_server.dart';
import '../services/project_service.dart';
import '../widgets/debug_console.dart';
import '../widgets/syntax_editor.dart';
import 'ai_screen.dart';
import 'preview_screen.dart';
import 'share_screen.dart';

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
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomAppBar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final previewCode = controller?.text;
                    if (previewCode == null) return;
                    final saved = await _save(announce: false);
                    final compiled = saved && await _compile(announce: false);
                    if (!mounted || !compiled) return;
                    await navigator.push(
                      MaterialPageRoute(
                        builder: (_) => PreviewScreen(code: previewCode),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Preview app'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AIScreen(projectName: widget.projectName),
                      ),
                    );
                    if (result != null) await _applyAiCode(result);
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Ask Sprout'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyAiCode(String code) async {
    final controller = _controller;
    if (controller == null) return;
    controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    final saved = await _save(announce: false);
    if (!mounted) return;
    if (saved) {
      setState(() => _aiFeedback = 'Your tailored app was applied and saved.');
      _showMessage(
          'Your tailored app is active. Preview it when you are ready.');
    }
  }
}
