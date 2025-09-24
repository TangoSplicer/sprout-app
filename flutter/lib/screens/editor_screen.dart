// flutter/lib/screens/editor_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'preview_screen.dart';
import 'ai_screen.dart';
import 'share_screens.dart';
import '../services/project_service.dart';
import '../services/reactive_runtime.dart';
import '../widgets/debug_console.dart';
import '../widgets/syntax_editor.dart';
import '../services/language_server.dart';
import '../services/debugger.dart';
import '../services/install_service.dart';

class EditorScreen extends StatefulWidget {
  final String projectName;

  const EditorScreen({super.key, required this.projectName});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Future<String> _codeFuture;
  late TextEditingController _controller;
  bool _showConsole = false;
  final SproutDebugger _debugger = SproutDebugger();
  final LanguageServerClient _ls = LanguageServerClient();
  String? _aiFeedback;

  @override
  void initState() {
    super.initState();
    _codeFuture = ProjectService().readFile(widget.projectName, 'main.sprout');
    _codeFuture.then((content) {
      if (mounted) {
        setState(() {
          _controller = TextEditingController(text: content);
        });
        _ls.notifyChange(content); // Sync to language server
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _compile() async {
    final code = _controller.text;
    _debugger.clear();

    try {
      final wasm = await ProjectService().compileCode(code);
      if (wasm.isNotEmpty) {
        _debugger.log("Compiled to native app structure");
      } else {
        _debugger.error("Compiler returned empty output");
      }
    } catch (e, stack) {
      _debugger.error("Compile error: $e", stack: stack);
    }
  }

  Future<void> _save() async {
    try {
      await ProjectService().writeFile(widget.projectName, 'main.sprout', _controller.text);
      _debugger.log("Saved to project");
      await _ls.notifyChange(_controller.text); // Update language server
    } catch (e, stack) {
      _debugger.error("Save failed: $e", stack: stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.projectName}.sprout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              setState(() {
                _showConsole = !_showConsole;
              });
            },
            color: _debugger.errors.isEmpty ? null : Colors.red,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShareScreen(projectName: widget.projectName),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _codeFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Expanded(
                child: SyntaxEditor(
                  text: snapshot.data!,
                  onChanged: (text) async {
                    _controller.value = TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                    await _ls.notifyChange(text); // Live feedback
                  },
                ),
              ),
              if (_showConsole)
                Column(
                  children: [
                    const Divider(height: 1),
                    DebugConsole(
                      logs: _debugger.logs.map((e) => e.message).toList(),
                      errors: _debugger.errors.map((e) => e.message).toList(),
                      aiFeedback: _aiFeedback,
                    ),
                  ],
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save',
                onPressed: _save,
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Run',
                onPressed: () async {
                  await _compile();
                  if (_debugger.errors.isEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PreviewScreen(code: _controller.text),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.robot),
                tooltip: 'AI Assistant',
                onPressed: () async {
                  final result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AIScreen(projectName: widget.projectName),
                    ),
                  );
                  if (result != null && mounted) {
                    _controller.text = result;
                    _setAiFeedback("AI code inserted");
                    await _ls.notifyChange(result);
                  }
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.install_mobile),
                tooltip: 'Install',
                onPressed: () async {
                  await _save();
                  await _compile();
                  if (_debugger.errors.isEmpty) {
                    try {
                      await InstallService.installApp(widget.projectName);
                      _debugger.log("Install started");
                    } catch (e, stack) {
                      _debugger.error("Install failed: $e", stack: stack);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setAiFeedback(String feedback) {
    setState(() {
      _aiFeedback = feedback;
    });
  }
}