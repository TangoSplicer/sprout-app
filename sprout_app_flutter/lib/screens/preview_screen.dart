import 'dart:async';

import 'package:flutter/material.dart';

import 'package:permission_handler/permission_handler.dart';

import '../services/native_bridge.dart';
import '../services/project_service.dart';
import '../services/sprout_preview_document.dart';
import '../theme/sprout_theme.dart';
import '../widgets/preview_container.dart';

class PreviewScreen extends StatefulWidget {
  final String code;
  final String? projectName;

  const PreviewScreen({
    super.key,
    required this.code,
    this.projectName,
  });

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
      final projectName = widget.projectName;
      if (projectName != null) {
        document.restoreState(await ProjectService().readAppState(projectName));
      }
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

  void _persistState() {
    final document = _document;
    final projectName = widget.projectName;
    if (document == null || projectName == null) return;
    unawaited(
        ProjectService().writeAppState(projectName, document.exportState()));
  }

  Future<void> _resetSavedData() async {
    final projectName = widget.projectName;
    if (projectName == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset this app’s saved data?'),
        content: const Text(
          'This clears entries, forms, and other local data for this project. Your app source and design stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep data'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ProjectService().clearAppState(projectName);
    for (final controller in _inputControllers.values) {
      controller.dispose();
    }
    _inputControllers.clear();
    await _loadPreview();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved app data was reset.')),
      );
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
    final theme = SproutTheme.light(preset: document?.theme ?? 'Forest');

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(document?.appName ?? 'Preview'),
          leading:
              document != null && document.screenName != document.startScreen
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      onPressed: _goBack,
                    )
                  : null,
          actions: [
            if (widget.projectName != null)
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded),
                tooltip: 'Reset saved app data',
                onPressed: _resetSavedData,
              ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState()
                  : _buildPreview(document!),
        ),
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
            onChanged: (value) {
              document.updateInput(binding, value);
              _persistState();
            },
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: placeholder,
              hintText: placeholder,
            ),
          ),
        ),
      SproutPreviewTextArea(:final placeholder, :final binding) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _controllerFor(binding),
            minLines: 4,
            maxLines: 8,
            onChanged: (value) {
              document.updateInput(binding, value);
              _persistState();
            },
            decoration: InputDecoration(
              alignLabelWithHint: true,
              labelText: placeholder,
              hintText: placeholder,
            ),
          ),
        ),
      SproutPreviewNumberInput(:final placeholder, :final binding) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _controllerFor(binding),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              document.updateInput(binding, value);
              _persistState();
            },
            decoration: InputDecoration(
              prefixText: '£ ',
              labelText: placeholder,
              hintText: '0.00',
            ),
          ),
        ),
      SproutPreviewChoice(:final label, :final options, :final binding) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.resolveTemplate(label),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in options)
                      ChoiceChip(
                        label: Text(option),
                        selected:
                            document.choiceValue(binding, options) == option,
                        onSelected: (_) {
                          setState(() => document.updateInput(binding, option));
                          _persistState();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      SproutPreviewProgress(
        :final label,
        :final valueBinding,
        :final totalBinding
      ) =>
        _buildProgress(
          document.resolveTemplate(label),
          document.metricValue(valueBinding),
          document.metricValue(totalBinding),
          document.progressValue(valueBinding, totalBinding),
        ),
      SproutPreviewRecordList(
        :final binding,
        :final fields,
        :final searchBinding,
        :final filterBinding,
        :final editable,
      ) =>
        _buildRecordList(
          binding,
          fields,
          searchBinding: searchBinding,
          filterBinding: filterBinding,
          editable: editable,
        ),
      SproutPreviewBreakdown(
        :final label,
        :final collection,
        :final amountField,
        :final kinds,
      ) =>
        _buildBreakdown(
          document.resolveTemplate(label),
          document.breakdownValues(collection, amountField, kinds),
        ),
      SproutPreviewAggregate(
        :final label,
        :final collection,
        :final amountField,
        :final positiveKinds,
        :final negativeKinds,
      ) =>
        _buildAggregate(
          document.resolveTemplate(label),
          document.aggregateValue(
            collection,
            amountField,
            positiveKinds,
            negativeKinds,
          ),
        ),
      SproutPreviewList(:final binding) => _buildList(binding),
      SproutPreviewSection(:final title, :final detail) => _buildSection(
          document.resolveTemplate(title),
          detail == null ? null : document.resolveTemplate(detail),
        ),
      SproutPreviewMetric(:final label, :final binding) => _buildMetric(
          document.resolveTemplate(label),
          document.metricValue(binding),
        ),
      SproutPreviewToggle(:final label, :final binding) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: SwitchListTile.adaptive(
            value: document.toggleValue(binding),
            onChanged: (value) {
              setState(() => document.updateToggle(binding, value));
              _persistState();
            },
            title: Text(document.resolveTemplate(label)),
          ),
        ),
      SproutPreviewDivider() => const Divider(height: 32),
      SproutPreviewChart(:final title, :final collection, :final amountField, :final chartType) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        document.resolveTemplate(title),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    Chip(
                      label: Text(chartType.toUpperCase(), style: const TextStyle(fontSize: 10)),
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...document.recordListValue(collection).take(5).map((record) {
                  final name = record['label']?.toString() ?? record['name']?.toString() ?? 'Entry';
                  final amount = record[amountField] is num ? (record[amountField] as num).toDouble() : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('$amount', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (amount / 100.0).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      SproutPreviewAudioPlayer(:final label, :final source) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.resolveTemplate(label),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        source,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.volume_up_rounded, color: Theme.of(context).colorScheme.primary),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Playing audio clip...')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      SproutPreviewCamera(:final label, :final binding) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      child: Icon(Icons.camera_alt_rounded, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.resolveTemplate(label),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            document.resolveTemplate(binding).isEmpty ? 'No photo captured yet' : 'Captured: ${document.resolveTemplate(binding)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _handlePhoto(SproutPreviewPhotoRequest(binding)),
                    icon: const Icon(Icons.camera_rounded),
                    label: const Text('Capture Photo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      SproutPreviewButton(:final label) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton(
            onPressed: () => _activate(element),
            child: Text(label),
          ),
        ),
    };
  }

  Widget _buildSection(String title, String? detail) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAggregate(String label, double value) {
    final scheme = Theme.of(context).colorScheme;
    final isPositive = value >= 0;
    final amount = '£${value.abs().toStringAsFixed(2)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isPositive ? scheme.primaryContainer : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isPositive
                  ? Icons.savings_outlined
                  : Icons.account_balance_wallet_outlined,
              color: isPositive ? scheme.primary : scheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Text(
              '${isPositive ? '' : '-'}$amount',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isPositive ? scheme.primary : scheme.error,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordList(
    String binding,
    List<String> fields, {
    String? searchBinding,
    String? filterBinding,
    required bool editable,
  }) {
    final document = _document!;
    final entries = document.filteredRecordEntries(
      binding,
      fields,
      searchBinding: searchBinding,
      filterBinding: filterBinding,
    );
    final total = document.recordListValue(binding).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            if (searchBinding != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _controllerFor(searchBinding),
                  onChanged: (value) {
                    setState(() => document.updateInput(searchBinding, value));
                    _persistState();
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: 'Search entries',
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing ${entries.length} of $total entries',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  total == 0
                      ? 'No entries yet. Use the form above to add your first one.'
                      : 'No entries match the current search or filter.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final record = entry.record;
                  final title = record[fields.first]?.toString() ?? 'Entry';
                  final detail = fields
                      .skip(1)
                      .map((field) {
                        final value = record[field];
                        if (field == 'amount' && value is num) {
                          return '£${value.toStringAsFixed(2)}';
                        }
                        return value?.toString() ?? '';
                      })
                      .where((value) => value.isNotEmpty)
                      .join(' · ');
                  return ListTile(
                    leading: CircleAvatar(child: Text('${entry.index + 1}')),
                    title: Text(title),
                    subtitle: detail.isEmpty ? null : Text(detail),
                    trailing: editable
                        ? Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: 'Edit entry',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _editRecord(binding, entry, fields),
                              ),
                              IconButton(
                                tooltip: 'Delete entry',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() => document.deleteRecord(
                                      binding, entry.index));
                                  _persistState();
                                },
                              ),
                            ],
                          )
                        : null,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdown(String label, Map<String, double> values) {
    final total = values.values.fold<double>(0, (sum, value) => sum + value);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            for (final entry in values.entries) ...[
              Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  Text('£${entry.value.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 6),
            ],
            const Divider(),
            Row(
              children: [
                const Expanded(
                    child: Text('Total',
                        style: TextStyle(fontWeight: FontWeight.w800))),
                Text('£${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editRecord(
    String binding,
    SproutPreviewRecordEntry entry,
    List<String> fields,
  ) async {
    final controllers = <String, TextEditingController>{
      for (final field in fields)
        field:
            TextEditingController(text: entry.record[field]?.toString() ?? ''),
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: controllers[field],
                    keyboardType: field == 'amount'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    decoration: InputDecoration(labelText: field),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      final updates = <String, Object?>{
        for (final field in fields)
          field: field == 'amount'
              ? double.tryParse(controllers[field]!.text) ?? 0
              : controllers[field]!.text,
      };
      setState(() => _document!.updateRecord(binding, entry.index, updates));
      _persistState();
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Widget _buildProgress(String label, num value, num total, double progress) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text('$value / $total'),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, num value) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
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

  Future<void> _activate(SproutPreviewButton button) async {
    late final List<SproutPreviewEffect> effects;
    setState(() {
      effects = _document!.activate(button);
      for (final entry in _inputControllers.entries) {
        final value = _document!.inputValue(entry.key);
        if (entry.value.text != value) entry.value.text = value;
      }
    });

    _persistState();

    for (final effect in effects) {
      if (effect is SproutPreviewReminderRequest) {
        await _scheduleReminder(effect);
      } else if (effect is SproutPreviewScanRequest) {
        await _handleScan(effect);
      } else if (effect is SproutPreviewPhotoRequest) {
        await _handlePhoto(effect);
      }
    }
  }

  Future<void> _handleScan(SproutPreviewScanRequest request) async {
    final result = await NativeBridge.scanQrCode();
    if (result != null && mounted) {
      setState(() {
        _document!.updateInput(request.binding, result);
        _controllerFor(request.binding).text = result;
      });
      _persistState();
    }
  }

  Future<void> _handlePhoto(SproutPreviewPhotoRequest request) async {
    final result = await NativeBridge.takePhoto();
    if (result != null && mounted) {
      setState(() {
        _document!.updateInput(request.binding, result);
        _controllerFor(request.binding).text = result;
      });
      _persistState();
    }
  }

  Future<void> _scheduleReminder(SproutPreviewReminderRequest reminder) async {
    final message = reminder.message.trim();
    final scheduledFor = _nextOccurrence(reminder.time);
    if (message.isEmpty || scheduledFor == null) {
      _showMessage(
        'Enter a reminder and a time such as 09:00 before scheduling.',
        error: true,
      );
      return;
    }

    final notificationPermission = await Permission.notification.request();
    if (!notificationPermission.isGranted) {
      if (mounted) {
        _showMessage(
          'Allow notifications to receive this reminder.',
          error: true,
        );
      }
      return;
    }

    try {
      await NativeBridge.scheduleAlarm(
        message,
        scheduledFor.millisecondsSinceEpoch,
      );
      if (mounted) {
        _showMessage('Reminder set for ${_formatTime(scheduledFor)}.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('This reminder could not be scheduled.', error: true);
      }
    }
  }

  DateTime? _nextOccurrence(String rawTime) {
    final match =
        RegExp(r'^(?:[01]?\d|2[0-3]):[0-5]\d$').firstMatch(rawTime.trim());
    if (match == null) return null;
    final parts = rawTime.trim().split(':');
    final now = DateTime.now();
    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  void _goBack() {
    setState(() {
      _document!.activate(
        const SproutPreviewButton('Back', [SproutPreviewNavigate('Back')]),
      );
    });
  }
}
