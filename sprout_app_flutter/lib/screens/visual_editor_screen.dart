import 'package:flutter/material.dart';

import '../theme/sprout_theme.dart';

class VisualEditorScreen extends StatefulWidget {
  final String projectName;
  final String initialSource;

  const VisualEditorScreen({
    super.key,
    required this.projectName,
    required this.initialSource,
  });

  @override
  State<VisualEditorScreen> createState() => _VisualEditorScreenState();
}

class _VisualEditorScreenState extends State<VisualEditorScreen> {
  late String _appName;
  String _theme = 'Forest';
  final List<_VisualComponent> _components = [];

  @override
  void initState() {
    super.initState();
    _parseSource(widget.initialSource);
  }

  void _parseSource(String source) {
    // Extract app name and theme
    final appMatch = RegExp(r'app\s+"([^"]+)"').firstMatch(source);
    _appName = appMatch?.group(1) ?? widget.projectName;
    _theme = RegExp(r'theme\s*=\s*"([^"]+)"').firstMatch(source)?.group(1) ??
        'Forest';

    // Simple heuristic parser for existing elements to populate visual builder
    _components.clear();
    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('label ')) {
        final val = trimmed.substring(6).replaceAll('"', '').trim();
        _components
            .add(_VisualComponent(type: _ComponentType.label, label: val));
      } else if (trimmed.startsWith('input ')) {
        final match = RegExp(r'input\s+"([^"]+)"\s*->\s*([A-Za-z0-9_]+)')
            .firstMatch(trimmed);
        if (match != null) {
          _components.add(_VisualComponent(
            type: _ComponentType.input,
            label: match.group(1) ?? '',
            binding: match.group(2) ?? 'textInput',
          ));
        }
      } else if (trimmed.startsWith('number ')) {
        final match = RegExp(r'number\s+"([^"]+)"\s*->\s*([A-Za-z0-9_]+)')
            .firstMatch(trimmed);
        if (match != null) {
          _components.add(_VisualComponent(
            type: _ComponentType.number,
            label: match.group(1) ?? '',
            binding: match.group(2) ?? 'numVal',
          ));
        }
      } else if (trimmed.startsWith('metric ')) {
        final match = RegExp(r'metric\s+"([^"]+)"\s*->\s*([A-Za-z0-9_]+)')
            .firstMatch(trimmed);
        if (match != null) {
          _components.add(_VisualComponent(
            type: _ComponentType.metric,
            label: match.group(1) ?? '',
            binding: match.group(2) ?? 'metricVal',
          ));
        }
      } else if (trimmed.startsWith('list ')) {
        final binding = trimmed.substring(5).trim();
        _components.add(_VisualComponent(
          type: _ComponentType.list,
          label: 'List: $binding',
          binding: binding,
        ));
      } else if (trimmed.startsWith('button ')) {
        final match = RegExp(r'button\s+"([^"]+)"').firstMatch(trimmed);
        if (match != null) {
          _components.add(_VisualComponent(
            type: _ComponentType.button,
            label: match.group(1) ?? 'Action',
          ));
        }
      }
    }

    if (_components.isEmpty) {
      _components.addAll([
        const _VisualComponent(
            type: _ComponentType.label, label: 'Welcome to your app!'),
        const _VisualComponent(
            type: _ComponentType.input,
            label: 'Type something',
            binding: 'userText'),
        const _VisualComponent(type: _ComponentType.button, label: 'Save note'),
      ]);
    }
  }

  String _generateSource() {
    final buffer = StringBuffer();
    buffer.writeln('app "$_appName" {');
    buffer.writeln('  start = "Home"');
    buffer.writeln('  theme = "$_theme"');
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln('screen Home {');
    // Collect state bindings
    final bindings = _components
        .where((c) => c.binding.isNotEmpty)
        .map((c) => c.binding)
        .toSet();
    for (final b in bindings) {
      buffer.writeln('  state $b = ""');
    }
    buffer.writeln('  ui {');
    buffer.writeln('    column {');
    buffer.writeln('      title "Visual Builder App"');

    for (final c in _components) {
      switch (c.type) {
        case _ComponentType.label:
          buffer.writeln('      label "${c.label}"');
          break;
        case _ComponentType.input:
          buffer.writeln('      input "${c.label}" -> ${c.binding}');
          break;
        case _ComponentType.number:
          buffer.writeln('      number "${c.label}" -> ${c.binding}');
          break;
        case _ComponentType.metric:
          buffer.writeln('      metric "${c.label}" -> ${c.binding}');
          break;
        case _ComponentType.list:
          buffer.writeln('      list ${c.binding}');
          break;
        case _ComponentType.button:
          buffer.writeln('      button "${c.label}" {');
          if (c.binding.isNotEmpty) {
            buffer.writeln('        ${c.binding}.append("Updated")');
          } else {
            buffer.writeln('        // Action');
          }
          buffer.writeln('      }');
          break;
        case _ComponentType.sync:
          buffer.writeln('      button "${c.label}" {');
          buffer.writeln('        sync ${c.binding}');
          buffer.writeln('      }');
          break;
        case _ComponentType.notify:
          buffer.writeln('      button "${c.label}" {');
          buffer.writeln('        notify "${c.binding}"');
          buffer.writeln('      }');
          break;
        case _ComponentType.chart:
          buffer.writeln('      chart "${c.label}" items amount by bar');
          break;
        case _ComponentType.audio:
          buffer.writeln('      audio "${c.label}" -> ${c.binding}');
          break;
        case _ComponentType.camera:
          buffer.writeln('      camera "${c.label}" -> ${c.binding}');
          break;
        case _ComponentType.scan:
          buffer.writeln('      button "${c.label}" {');
          buffer.writeln('        scan -> ${c.binding}');
          buffer.writeln('      }');
          break;
      }
    }

    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln('}');
    return buffer.toString();
  }

  void _addComponent(_ComponentType type) {
    setState(() {
      switch (type) {
        case _ComponentType.label:
          _components.add(const _VisualComponent(
              type: _ComponentType.label, label: 'New label text'));
          break;
        case _ComponentType.input:
          _components.add(const _VisualComponent(
              type: _ComponentType.input,
              label: 'New field',
              binding: 'fieldInput'));
          break;
        case _ComponentType.number:
          _components.add(const _VisualComponent(
              type: _ComponentType.number,
              label: 'Amount',
              binding: 'amountVal'));
          break;
        case _ComponentType.metric:
          _components.add(const _VisualComponent(
              type: _ComponentType.metric,
              label: 'Total',
              binding: 'totalVal'));
          break;
        case _ComponentType.list:
          _components.add(const _VisualComponent(
              type: _ComponentType.list, label: 'Items', binding: 'itemsList'));
          break;
        case _ComponentType.button:
          _components.add(const _VisualComponent(
              type: _ComponentType.button, label: 'Perform Action'));
          break;
        case _ComponentType.sync:
          _components.add(const _VisualComponent(
              type: _ComponentType.sync,
              label: 'Sync with peers',
              binding: 'itemsList'));
          break;
        case _ComponentType.notify:
          _components.add(const _VisualComponent(
              type: _ComponentType.notify,
              label: 'Send notification',
              binding: 'Update completed!'));
          break;
        case _ComponentType.chart:
          _components.add(const _VisualComponent(
              type: _ComponentType.chart, label: 'Spending Breakdown'));
          break;
        case _ComponentType.audio:
          _components.add(const _VisualComponent(
              type: _ComponentType.audio,
              label: 'Voice Note',
              binding: 'voiceNote'));
          break;
        case _ComponentType.camera:
          _components.add(const _VisualComponent(
              type: _ComponentType.camera,
              label: 'Take Photo',
              binding: 'photoPath'));
          break;
        case _ComponentType.scan:
          _components.add(const _VisualComponent(
              type: _ComponentType.scan,
              label: 'Scan QR Code',
              binding: 'scannedData'));
          break;
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _components.removeAt(index));
  }

  Widget _buildThemePicker() {
    final themes = ['Forest', 'Ocean', 'Sunset', 'Minimal'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Text('App Style:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: themes.map((t) {
                  final isSelected = _theme == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _theme = t);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Component Builder'),
        actions: [
          FilledButton.icon(
            onPressed: () {
              final code = _generateSource();
              Navigator.pop(context, code);
            },
            icon: const Icon(Icons.check),
            label: const Text('Apply to code'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: SproutTheme.peach,
              child: const Row(
                children: [
                  Icon(Icons.widgets_outlined, color: SproutTheme.forest),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Build your app visually by adding components below. Sprout generates clean, secure code automatically.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            _buildThemePicker(),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _components.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _components.removeAt(oldIndex);
                    _components.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final item = _components[index];
                  return Card(
                    key: ValueKey(item),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(_iconForType(item.type),
                          color: SproutTheme.forest),
                      title: Text(item.label,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${item.type.name.toUpperCase()}${item.binding.isNotEmpty ? ' • ${item.binding}' : ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () => _removeItem(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Add component:',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    ActionChip(
                      avatar: const Icon(Icons.text_fields, size: 16),
                      label: const Text('Label'),
                      onPressed: () => _addComponent(_ComponentType.label),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.input, size: 16),
                      label: const Text('Input'),
                      onPressed: () => _addComponent(_ComponentType.input),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.pin, size: 16),
                      label: const Text('Number'),
                      onPressed: () => _addComponent(_ComponentType.number),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.analytics_outlined, size: 16),
                      label: const Text('Metric'),
                      onPressed: () => _addComponent(_ComponentType.metric),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.list_alt, size: 16),
                      label: const Text('List'),
                      onPressed: () => _addComponent(_ComponentType.list),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.smart_button, size: 16),
                      label: const Text('Button'),
                      onPressed: () => _addComponent(_ComponentType.button),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Sync P2P'),
                      onPressed: () => _addComponent(_ComponentType.sync),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.notifications_active_outlined,
                          size: 16),
                      label: const Text('Notify'),
                      onPressed: () => _addComponent(_ComponentType.notify),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.bar_chart_rounded, size: 16),
                      label: const Text('Chart'),
                      onPressed: () => _addComponent(_ComponentType.chart),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.audiotrack_rounded, size: 16),
                      label: const Text('Audio'),
                      onPressed: () => _addComponent(_ComponentType.audio),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.camera_alt_rounded, size: 16),
                      label: const Text('Camera'),
                      onPressed: () => _addComponent(_ComponentType.camera),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar:
                          const Icon(Icons.qr_code_scanner_rounded, size: 16),
                      label: const Text('Scan'),
                      onPressed: () => _addComponent(_ComponentType.scan),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(_ComponentType type) {
    switch (type) {
      case _ComponentType.label:
        return Icons.text_fields;
      case _ComponentType.input:
        return Icons.input;
      case _ComponentType.number:
        return Icons.pin;
      case _ComponentType.metric:
        return Icons.analytics_outlined;
      case _ComponentType.list:
        return Icons.list_alt;
      case _ComponentType.button:
        return Icons.smart_button;
      case _ComponentType.sync:
        return Icons.sync_rounded;
      case _ComponentType.notify:
        return Icons.notifications_active_outlined;
      case _ComponentType.chart:
        return Icons.bar_chart_rounded;
      case _ComponentType.audio:
        return Icons.audiotrack_rounded;
      case _ComponentType.camera:
        return Icons.camera_alt_rounded;
      case _ComponentType.scan:
        return Icons.qr_code_scanner_rounded;
    }
  }
}

enum _ComponentType {
  label,
  input,
  number,
  metric,
  list,
  button,
  sync,
  notify,
  chart,
  audio,
  camera,
  scan
}

class _VisualComponent {
  final _ComponentType type;
  final String label;
  final String binding;

  const _VisualComponent({
    required this.type,
    required this.label,
    this.binding = '',
  });
}
