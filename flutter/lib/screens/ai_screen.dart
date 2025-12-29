// flutter/lib/screens/ai_screen.dart
import 'package:flutter/material.dart';
import '../services/ai_assistant.dart';

class AIScreen extends StatefulWidget {
  final String projectName;

  const AIScreen({super.key, required this.projectName});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final TextEditingController _promptController = TextEditingController();
  String _generatedCode = '';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'Describe your app',
                hintText: 'e.g., "A to-do list with priorities"',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.robot),
                label: Text(_loading ? 'Thinking...' : 'Generate'),
                onPressed: _loading
                    ? null
                    : () async {
                        setState(() {
                          _loading = true;
                          _generatedCode = '';
                        });
                        final code = await AIAssistant().generate(_promptController.text);
                        setState(() {
                          _generatedCode = code;
                          _loading = false;
                        });
                      },
              ),
            ),
            const SizedBox(height: 24),
            if (_loading) const LinearProgressIndicator(),
            if (_generatedCode.isNotEmpty) ...[
              const Text('Generated Code:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _generatedCode,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await ProjectService().writeFile(widget.projectName, 'main.sprout', _generatedCode);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code saved!')),
                          );
                        }
                      },
                      child: const Text('Save & Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _generatedCode);
                    },
                    child: const Text('Use'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
}