import 'package:flutter/material.dart';

import '../services/ai_assistant.dart';
import '../services/project_service.dart';
import '../theme/sprout_theme.dart';

class AIScreen extends StatefulWidget {
  final String projectName;

  const AIScreen({super.key, required this.projectName});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _generatedController = TextEditingController();
  final Set<String> _selectedOptions = <String>{};
  bool _loading = false;
  String? _validationMessage;

  static const _presets = <_CreationPreset>[
    _CreationPreset(
      'Ranked tasks',
      'A ranked todo list for my most important tasks',
      Icons.format_list_numbered,
    ),
    _CreationPreset(
      'Reminders',
      'A daily reminder app with alarms for my routine',
      Icons.notifications_active_outlined,
    ),
    _CreationPreset(
      'Event planner',
      'An event planner with appointment reminders',
      Icons.event_available_outlined,
    ),
    _CreationPreset(
      'Shopping',
      'A grocery shopping list for my weekend plans',
      Icons.shopping_basket_outlined,
    ),
    _CreationPreset(
      'Notes',
      'A quick note catcher for work ideas',
      Icons.sticky_note_2_outlined,
    ),
    _CreationPreset(
      'Habit check-in',
      'A daily habit check-in for a healthier routine',
      Icons.favorite_outline,
    ),
    _CreationPreset(
      'Focus sessions',
      'A focus session tracker for deep work and study',
      Icons.timer_outlined,
    ),
    _CreationPreset(
      'Wellness check-in',
      'A wellness and mood check-in for a calmer routine',
      Icons.spa_outlined,
    ),
    _CreationPreset(
      'Personal budget',
      'A personal budget and spending decision tracker',
      Icons.account_balance_wallet_outlined,
    ),
    _CreationPreset(
      'Meal planner',
      'A meal planner for simple weekday dinners',
      Icons.restaurant_menu_outlined,
    ),
    _CreationPreset(
      'Reading list',
      'A reading list and book completion tracker',
      Icons.menu_book_outlined,
    ),
  ];

  static const _options = <_CreationOption>[
    _CreationOption('Interactive input', 'a form input that users can edit'),
    _CreationOption(
        'Progress metric', 'a visible completion or progress metric'),
    _CreationOption(
        'Personal preference', 'a toggle for a meaningful user preference'),
    _CreationOption('Local reminder', 'a local reminder with a time field'),
    _CreationOption('Extra screen', 'a second help or settings screen'),
  ];

  @override
  void dispose() {
    _promptController.dispose();
    _generatedController.dispose();
    super.dispose();
  }

  String get _generatedCode => _generatedController.text;

  Future<void> _generate() async {
    final description = _promptController.text.trim();
    if (description.isEmpty) {
      _showMessage('Describe the small app you want to make first.',
          error: true);
      return;
    }
    setState(() {
      _loading = true;
      _validationMessage = null;
    });
    try {
      final code =
          await AIAssistant().generate(_requestWithOptions(description));
      if (!mounted) return;
      setState(() {
        _generatedController.text = code;
        _loading = false;
      });
      _showMessage('Starter created. You can edit every line before using it.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Sprout could not create that starter. Please try again.',
          error: true);
    }
  }

  String _requestWithOptions(String description) {
    if (_selectedOptions.isEmpty) return description;
    final details = _options
        .where((option) => _selectedOptions.contains(option.label))
        .map((option) => option.requestDetail)
        .join(', ');
    return '$description. Include $details.';
  }

  void _usePreset(_CreationPreset preset) {
    setState(() {
      _promptController.text = preset.prompt;
      _validationMessage = null;
    });
  }

  Future<void> _validate() async {
    if (_generatedCode.trim().isEmpty) return;
    try {
      await ProjectService().compileCode(_generatedCode);
      if (!mounted) return;
      setState(() =>
          _validationMessage = 'Ready to preview: source compiled cleanly.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _validationMessage = 'Check the source before using it.');
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
    if (_generatedCode.trim().isEmpty) return;
    try {
      await ProjectService()
          .writeFile(widget.projectName, 'main.sprout', _generatedCode);
      if (!mounted) return;
      _showMessage('Saved to ${widget.projectName}.');
      Navigator.pop(context, _generatedCode);
    } catch (_) {
      _showMessage('Could not save this app.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGeneratedCode = _generatedCode.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sprout Studio'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Guided app creation for ${widget.projectName}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntro(scheme),
                    const SizedBox(height: 24),
                    Text('Start with a tool',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    _buildPresetGrid(),
                    const SizedBox(height: 24),
                    Text('Describe what you need',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _promptController,
                      minLines: 3,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Your app idea',
                        hintText:
                            'For example: a grocery list for a weekend barbecue',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Add useful building blocks',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Select the parts you want Sprout to account for in the starter.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _options
                          .map(
                            (option) => FilterChip(
                              label: Text(option.label),
                              selected: _selectedOptions.contains(option.label),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _selectedOptions.add(option.label);
                                } else {
                                  _selectedOptions.remove(option.label);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _generate,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(_loading
                            ? 'Creating your starter…'
                            : 'Create editable starter'),
                      ),
                    ),
                    if (hasGeneratedCode) ...[
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Editable source',
                                style: Theme.of(context).textTheme.titleLarge),
                          ),
                          OutlinedButton.icon(
                            onPressed: _validate,
                            icon: const Icon(Icons.verified_outlined, size: 18),
                            label: const Text('Check'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Change the labels, screens, and actions here. The editor will receive exactly this version.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      if (_validationMessage != null) ...[
                        const SizedBox(height: 10),
                        _StatusNote(message: _validationMessage!),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 420,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF252A27),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: _generatedController,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            textAlignVertical: TextAlignVertical.top,
                            keyboardType: TextInputType.multiline,
                            style: const TextStyle(
                              color: Color(0xFFF9F6F0),
                              fontFamily: 'monospace',
                              fontSize: 13,
                              height: 1.45,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.all(16),
                              border: InputBorder.none,
                              filled: false,
                            ),
                            onChanged: (_) =>
                                setState(() => _validationMessage = null),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: hasGeneratedCode
          ? Material(
              color: Theme.of(context).bottomAppBarTheme.color,
              elevation: Theme.of(context).bottomAppBarTheme.elevation ?? 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              Navigator.pop(context, _generatedCode),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Use this in my app'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _saveAndClose,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save to project and close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildIntro(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SproutTheme.peach,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: scheme.primary, size: 34),
          const SizedBox(height: 12),
          Text('Your creation assistant is ready.',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text(
            'Choose a focused tool, describe the result, add the building blocks you need, then edit the source before applying it.',
          ),
        ],
      ),
    );
  }

  Widget _buildPresetGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
          ),
          itemCount: _presets.length,
          itemBuilder: (context, index) {
            final preset = _presets[index];
            return Semantics(
              button: true,
              label: '${preset.label} creation tool',
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _usePreset(preset),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(preset.icon,
                            color: Theme.of(context).colorScheme.primary),
                        const Spacer(),
                        Text(preset.label,
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CreationPreset {
  final String label;
  final String prompt;
  final IconData icon;

  const _CreationPreset(this.label, this.prompt, this.icon);
}

class _CreationOption {
  final String label;
  final String requestDetail;

  const _CreationOption(this.label, this.requestDetail);
}

class _StatusNote extends StatelessWidget {
  final String message;

  const _StatusNote({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: scheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}
