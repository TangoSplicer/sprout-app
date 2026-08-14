import 'package:flutter/material.dart';

import '../services/sprout_code_assistant.dart';
import '../services/sprout_language_catalog.dart';
import '../widgets/syntax_editor.dart';

class LanguageToolsScreen extends StatefulWidget {
  final String source;
  final String projectName;

  const LanguageToolsScreen({
    super.key,
    required this.source,
    required this.projectName,
  });

  @override
  State<LanguageToolsScreen> createState() => _LanguageToolsScreenState();
}

class _LanguageToolsScreenState extends State<LanguageToolsScreen> {
  final SproutCodeAssistant _assistant = const SproutCodeAssistant();
  late TextEditingController _controller;
  late List<SproutReviewFinding> _findings;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.source);
    _refreshReview();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refreshReview() {
    _findings = _assistant.review(_controller.text);
  }

  void _apply(SproutAmendment amendment) {
    setState(() {
      _controller.text = _assistant.apply(_controller.text, amendment);
      _refreshReview();
    });
  }

  void _insert(SproutLanguageSnippet snippet) {
    setState(() {
      _controller.text = _assistant.insertSnippet(_controller.text, snippet);
      _refreshReview();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${snippet.title} inserted into the first screen.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Review with Sprout'),
            Text(
              widget.projectName,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Recheck source',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(_refreshReview),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final review = _buildReview(context);
            final editor = _buildEditor(context);
            if (wide) {
              return Row(
                children: [
                  SizedBox(width: 350, child: review),
                  const VerticalDivider(width: 1),
                  Expanded(child: editor),
                ],
              );
            }
            return Column(
              children: [
                SizedBox(height: 285, child: review),
                const Divider(height: 1),
                Expanded(child: editor),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, _controller.text),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Use reviewed source'),
          ),
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Language review',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Local checks and controlled source amendments. Nothing is replaced automatically.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final finding in _findings) _findingCard(context, finding),
        const SizedBox(height: 14),
        Text(
          'Insert a language block',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final snippet in SproutLanguageCatalog.snippets)
              ActionChip(
                avatar: const Icon(Icons.add_circle_outline, size: 18),
                label: Text(snippet.title),
                onPressed: () => _insert(snippet),
              ),
          ],
        ),
      ],
    );
  }

  Widget _findingCard(BuildContext context, SproutReviewFinding finding) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (finding.severity) {
      SproutReviewSeverity.error => (Icons.error_outline, scheme.error),
      SproutReviewSeverity.warning => (
          Icons.warning_amber_rounded,
          Colors.orange.shade800
        ),
      SproutReviewSeverity.hint => (
          Icons.tips_and_updates_outlined,
          scheme.primary
        ),
      SproutReviewSeverity.good => (
          Icons.verified_outlined,
          Colors.green.shade700
        ),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    finding.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(finding.detail,
                      style: Theme.of(context).textTheme.bodySmall),
                  if (finding.amendment != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _apply(finding.amendment!),
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: const Text('Apply amendment'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Editable source',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Review every amendment, then keep or edit it before returning to your app.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SyntaxEditor(
              text: _controller.text,
              onChanged: (value) => _controller.value = TextEditingValue(
                text: value,
                selection: TextSelection.collapsed(offset: value.length),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
