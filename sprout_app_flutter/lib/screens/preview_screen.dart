import 'package:flutter/material.dart';

import '../services/project_service.dart';
import '../services/sprout_preview_document.dart';
import '../widgets/preview_container.dart';

class PreviewScreen extends StatefulWidget {
  final String code;

  const PreviewScreen({super.key, required this.code});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final Map<String, TextEditingController> _inputControllers = {};
  SproutPreviewDocument? _document;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ProjectService().compileCode(widget.code);
      final document = SproutPreviewDocument.parse(widget.code);
      if (!mounted) return;
      setState(() {
        _document = document;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _inputControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;

    return Scaffold(
      appBar: AppBar(
        title: Text(document?.appName ?? 'Preview'),
        leading: document != null && document.screenName != document.startScreen
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: _goBack,
              )
            : null,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : _buildPreview(document!),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'This app could not be previewed yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadPreview,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(SproutPreviewDocument document) {
    return PreviewContainer(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            document.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            document.screenName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 28),
          if (!document.hasVisibleContent)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'This screen has no visible elements yet.',
                textAlign: TextAlign.center,
              ),
            ),
          ...document.currentScreen.elements.map(_buildElement),
        ],
      ),
    );
  }

  Widget _buildElement(SproutPreviewElement element) {
    final document = _document!;
    return switch (element) {
      SproutPreviewLabel(:final text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            document.resolveTemplate(text),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      SproutPreviewInput(:final placeholder, :final binding) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _controllerFor(binding),
            onChanged: (value) => document.updateInput(binding, value),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: placeholder,
              hintText: placeholder,
            ),
          ),
        ),
      SproutPreviewList(:final binding) => _buildList(binding),
      SproutPreviewButton(:final label) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton(
            onPressed: () => _activate(element),
            child: Text(label),
          ),
        ),
    };
  }

  Widget _buildList(String binding) {
    final items = _document!.listValue(binding);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'No items yet. Add your first one above.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          for (final entry in items.indexed)
            ListTile(
              leading: CircleAvatar(child: Text('${entry.$1 + 1}')),
              title: Text(entry.$2),
            ),
        ],
      ),
    );
  }

  TextEditingController _controllerFor(String binding) {
    return _inputControllers.putIfAbsent(
      binding,
      () => TextEditingController(text: _document!.inputValue(binding)),
    );
  }

  void _activate(SproutPreviewButton button) {
    setState(() {
      _document!.activate(button);
      for (final entry in _inputControllers.entries) {
        final value = _document!.inputValue(entry.key);
        if (entry.value.text != value) entry.value.text = value;
      }
    });
  }

  void _goBack() {
    setState(() {
      _document!.activate(
        const SproutPreviewButton('Back', [SproutPreviewNavigate('Back')]),
      );
    });
  }
}
