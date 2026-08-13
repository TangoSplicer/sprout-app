import 'package:flutter/material.dart';

import '../services/ai_assistant.dart';
import '../services/project_service.dart';

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
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _showMessage('Describe the small app you want to make first.',
          error: true);
      return;
    }
    setState(() {
      _loading = true;
      _generatedCode = '';
    });
    try {
      final code = await AIAssistant().generate(prompt);
      if (!mounted) return;
      setState(() {
        _generatedCode = code;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Sprout could not create that starter. Please try again.',
          error: true);
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

  Future<void> _saveAndClose() async {
    try {
      await ProjectService()
          .writeFile(widget.projectName, 'main.sprout', _generatedCode);
      if (!mounted) return;
      _showMessage('Saved to ${widget.projectName}.');
      Navigator.pop(context);
    } catch (_) {
      _showMessage('Could not save this app.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGeneratedCode = _generatedCode.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Ask Sprout')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start with what you need',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sprout turns your description into a safe, editable starter. It uses your words to choose the structure, not a one-size-fits-all demo.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PromptChip(
                    label: 'Ranked weekly tasks',
                    onTap: () => _promptController.text =
                        'A ranked weekly todo list for my home chores',
                  ),
                  _PromptChip(
                    label: 'Groceries',
                    onTap: () => _promptController.text =
                        'A grocery shopping list for dinner planning',
                  ),
                  _PromptChip(
                    label: 'Quick notes',
                    onTap: () => _promptController.text =
                        'A quick note catcher for work ideas',
                  ),
                  _PromptChip(
                    label: 'Habit check-in',
                    onTap: () => _promptController.text =
                        'A daily habit check-in for stretching',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _promptController,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'What would you like to make?',
                  hintText:
                      'For example: a grocery list for a weekend barbecue',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _generate,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_loading
                      ? 'Creating your starter…'
                      : 'Create a tailored starter'),
                ),
              ),
              const SizedBox(height: 16),
              if (hasGeneratedCode) ...[
                Text(
                  'Your editable starter',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        _generatedCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: hasGeneratedCode
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saveAndClose,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save and close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, _generatedCode),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Use in my app'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.lightbulb_outline, size: 18),
      onPressed: onTap,
    );
  }
}
