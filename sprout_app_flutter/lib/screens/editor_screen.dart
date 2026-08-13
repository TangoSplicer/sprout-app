// flutter/lib/screens/editor_screen.dart
import 'package:flutter/material.dart';
import 'preview_screen.dart';
import 'ai_screen.dart';
import 'share_screen.dart';
import '../services/project_service.dart';
import '../widgets/debug_console.dart';
import '../widgets/syntax_editor.dart';
import '../services/language_server.dart';
import '../services/debugger.dart';

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
      await ProjectService()
          .writeFile(widget.projectName, 'main.sprout', _controller.text);
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
              Flexible(
                flex: _showConsole ? 3 : 1,
                child: SyntaxEditor(
                  text: _controller.text,
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
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      Expanded(
                        child: DebugConsole(
                          logs: _debugger.logs.map((e) => e.message).toList(),
                          errors:
                              _debugger.errors.map((e) => e.message).toList(),
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
                  if (!context.mounted) return;
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
                icon: const Icon(Icons.smart_toy),
                tooltip: 'AI Assistant',
                onPressed: () async {
                  final result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AIScreen(projectName: widget.projectName),
                    ),
                  );
                  if (result != null) {
                    await _applyAiCode(result);
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

  Future<void> _applyAiCode(String code) async {
    _controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );

    try {
      await ProjectService().writeFile(widget.projectName, 'main.sprout', code);
      await _ls.notifyChange(code);
      if (!mounted) return;
      _setAiFeedback('AI app applied and saved');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your generated app is now active.')),
      );
    } catch (error, stack) {
      _debugger.error('Could not save AI code: $error', stack: stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the generated app.')),
      );
    }
  }

  void _setAiFeedback(String feedback) {
    setState(() {
      _aiFeedback = feedback;
    });
  }
}
