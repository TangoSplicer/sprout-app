/// A bounded, local execution model for the previewable SproutScript surface.
///
/// Rust remains authoritative for source validation and compilation. This model
/// mirrors the supported interactive UI grammar so that a successful preview
/// reflects the document the user accepted, including text input, list changes,
/// and navigation.
class SproutPreviewDocument {
  final String appName;
  final String startScreen;
  final Map<String, SproutPreviewScreen> _screens;
  final Map<String, Object?> _state;
  final List<String> _navigationStack;

  SproutPreviewDocument._({
    required this.appName,
    required this.startScreen,
    required Map<String, SproutPreviewScreen> screens,
    required Map<String, Object?> state,
  })  : _screens = screens,
        _state = state,
        _navigationStack = [startScreen];

  factory SproutPreviewDocument.parse(String source) {
    final appName = RegExp(r'app\s+"([^"]+)"').firstMatch(source)?.group(1) ??
        'Untitled Sprout App';
    final screenBlocks = _extractNamedBlocks(source, 'screen');
    final screens = <String, SproutPreviewScreen>{};
    final state = <String, Object?>{};

    for (final block in screenBlocks) {
      final screen = _parseScreen(block.name, block.body, state);
      screens[screen.name] = screen;
    }

    if (screens.isEmpty) {
      screens['Home'] = const SproutPreviewScreen(
        name: 'Home',
        elements: [],
      );
    }

    final declaredStart = RegExp(
      r'^\s*start\s*=\s*"?([A-Za-z_]\w*)"?\s*$',
      multiLine: true,
    ).firstMatch(source)?.group(1);
    final startScreen = screens.containsKey(declaredStart)
        ? declaredStart!
        : screens.keys.first;

    return SproutPreviewDocument._(
      appName: appName,
      startScreen: startScreen,
      screens: screens,
      state: state,
    );
  }

  String get screenName => _navigationStack.last;

  SproutPreviewScreen get currentScreen => _screens[screenName]!;

  List<String> get labels => currentScreen.elements
      .whereType<SproutPreviewLabel>()
      .map((element) => resolveTemplate(element.text))
      .toList(growable: false);

  List<String> get buttons => currentScreen.elements
      .whereType<SproutPreviewButton>()
      .map((element) => element.label)
      .toList(growable: false);

  bool get hasVisibleContent => currentScreen.elements.isNotEmpty;

  Map<String, dynamic> exportState() => _state.map(
        (key, value) => MapEntry(key, _jsonValue(value)),
      );

  void restoreState(Map<String, dynamic> savedState) {
    for (final entry in savedState.entries) {
      if (!RegExp(r'^[A-Za-z_]\w*$').hasMatch(entry.key)) continue;
      _state[entry.key] = _restoreJsonValue(entry.value);
    }
  }

  static dynamic _jsonValue(Object? value) {
    if (value is Map) {
      return value.map((key, child) => MapEntry('$key', _jsonValue(child)));
    }
    if (value is List) return value.map(_jsonValue).toList(growable: false);
    return value;
  }

  static Object? _restoreJsonValue(Object? value) {
    if (value is Map) {
      return value
          .map((key, child) => MapEntry('$key', _restoreJsonValue(child)));
    }
    if (value is List) {
      return value.map(_restoreJsonValue).toList(growable: false);
    }
    return value;
  }

  String inputValue(String binding) => (_state[binding] as String?) ?? '';

  bool toggleValue(String binding) => (_state[binding] as bool?) ?? false;

  String choiceValue(String binding, List<String> options) {
    final value = _state[binding] as String?;
    if (value != null && options.contains(value)) return value;
    return options.first;
  }

  num metricValue(String binding) => (_state[binding] as num?) ?? 0;

  double progressValue(String valueBinding, String totalBinding) {
    final total = metricValue(totalBinding);
    if (total <= 0) return 0;
    return (metricValue(valueBinding) / total).clamp(0, 1).toDouble();
  }

  List<String> listValue(String binding) {
    final value = _state[binding];
    if (value is List) {
      return List.unmodifiable(value.whereType<String>());
    }
    return const [];
  }

  List<Map<String, Object?>> recordListValue(String binding) {
    final value = _state[binding];
    if (value is! List) return const [];
    return List.unmodifiable(
      value.whereType<Map>().map(
            (record) => Map<String, Object?>.from(record),
          ),
    );
  }

  List<SproutPreviewRecordEntry> filteredRecordEntries(
    String binding,
    List<String> fields, {
    String? searchBinding,
    String? filterBinding,
  }) {
    final query = searchBinding == null
        ? ''
        : inputValue(searchBinding).trim().toLowerCase();
    final filter = filterBinding == null
        ? ''
        : inputValue(filterBinding).trim().toLowerCase();
    return recordListValue(binding)
        .indexed
        .where((entry) {
          final record = entry.$2;
          final matchesQuery = query.isEmpty ||
              fields.any((field) => (record[field]?.toString() ?? '')
                  .toLowerCase()
                  .contains(query));
          final kind = (record['kind']?.toString() ?? '').toLowerCase();
          final matchesFilter =
              filter.isEmpty || filter == 'all' || kind.contains(filter);
          return matchesQuery && matchesFilter;
        })
        .map((entry) => SproutPreviewRecordEntry(entry.$1, entry.$2))
        .toList(growable: false);
  }

  void updateRecord(String binding, int index, Map<String, Object?> updates) {
    final values = List<Object?>.from(_state[binding] as List? ?? const []);
    if (index < 0 || index >= values.length || values[index] is! Map) return;
    final record = Map<String, Object?>.from(values[index] as Map);
    record.addAll(updates);
    values[index] = record;
    _state[binding] = values;
  }

  void deleteRecord(String binding, int index) {
    final values = List<Object?>.from(_state[binding] as List? ?? const []);
    if (index < 0 || index >= values.length) return;
    values.removeAt(index);
    _state[binding] = values;
  }

  Map<String, double> breakdownValues(
    String collection,
    String amountField,
    List<String> kinds,
  ) {
    return {
      for (final kind in kinds)
        kind: recordListValue(collection)
            .where((record) => record['kind']?.toString() == kind)
            .fold<double>(
                0, (total, record) => total + _asNumber(record[amountField])),
    };
  }

  double aggregateValue(
    String collection,
    String amountField,
    List<String> positiveKinds,
    List<String> negativeKinds,
  ) {
    return recordListValue(collection).fold<double>(0, (total, record) {
      final kind = record['kind']?.toString();
      final amount = _asNumber(record[amountField]);
      if (positiveKinds.contains(kind)) return total + amount;
      if (negativeKinds.contains(kind)) return total - amount;
      return total;
    });
  }

  double _asNumber(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  void updateInput(String binding, String value) {
    _state[binding] = value.length > 1000 ? value.substring(0, 1000) : value;
  }

  void updateToggle(String binding, bool value) {
    _state[binding] = value;
  }

  List<SproutPreviewEffect> activate(SproutPreviewButton button) {
    final effects = <SproutPreviewEffect>[];
    for (final action in button.actions) {
      final effect = _runAction(action);
      if (effect != null) effects.add(effect);
    }
    return effects;
  }

  String resolveTemplate(String value) {
    return value.replaceAllMapped(RegExp(r'\$\{([^}]+)\}'), (match) {
      final stateValue = _state[match.group(1)!.trim()];
      if (stateValue is List<String>) return stateValue.join(', ');
      return stateValue?.toString() ?? '';
    });
  }

  bool _evaluateCondition(String condition) {
    // Basic condition evaluation for preview
    if (condition.contains('==')) {
      final parts = condition.split('==');
      return _resolveExpression(parts[0].trim()) ==
          _resolveExpression(parts[1].trim());
    }
    if (condition.contains('>')) {
      final parts = condition.split('>');
      final left = _asNumber(_resolveExpression(parts[0].trim()));
      final right = _asNumber(_resolveExpression(parts[1].trim()));
      return left > right;
    }
    if (condition.contains('<')) {
      final parts = condition.split('<');
      final left = _asNumber(_resolveExpression(parts[0].trim()));
      final right = _asNumber(_resolveExpression(parts[1].trim()));
      return left < right;
    }
    final val = _resolveExpression(condition);
    return val == 'true';
  }

  SproutPreviewEffect? _runAction(SproutPreviewAction action) {
    switch (action) {
      case SproutPreviewNavigate(:final target):
        if (target == 'Back') {
          if (_navigationStack.length > 1) _navigationStack.removeLast();
        } else if (_screens.containsKey(target)) {
          _navigationStack.add(target);
        }
        return null;
      case SproutPreviewUpdate(:final variable, :final expression):
        _state[variable] = _resolveExpression(expression);
        return null;
      case SproutPreviewAppend(:final variable, :final expression):
        final values =
            List<Object?>.from(_state[variable] as List? ?? const []);
        if (values.length < 100) values.add(_resolveExpression(expression));
        _state[variable] = values;
        return null;
      case SproutPreviewAppendRecord(:final variable, :final fields):
        final values =
            List<Object?>.from(_state[variable] as List? ?? const []);
        if (values.length < 100) {
          final record = <String, Object?>{};
          for (final field in fields.entries) {
            final resolved = _resolveExpression(field.value);
            record[field.key] = field.key == 'amount'
                ? double.tryParse(resolved) ?? 0
                : resolved;
          }
          values.add(record);
        }
        _state[variable] = values;
        return null;
      case SproutPreviewRemove(:final variable, :final expression):
        final values =
            List<Object?>.from(_state[variable] as List? ?? const []);
        values.remove(_resolveExpression(expression));
        _state[variable] = values;
        return null;
      case SproutPreviewRemoveFirst(:final variable):
        final values =
            List<Object?>.from(_state[variable] as List? ?? const []);
        if (values.isNotEmpty) values.removeAt(0);
        _state[variable] = values;
        return null;
      case SproutPreviewIncrement(:final variable, :final by):
        _state[variable] = metricValue(variable) + by;
        return null;
      case SproutPreviewClear(:final variable):
        _state[variable] = const [];
        return null;
      case SproutPreviewFetch(:final url, :final bindTo):
        _state[bindTo] = 'Fetched data from $url';
        return null;
      case SproutPreviewScan(:final bindTo):
        return SproutPreviewScanRequest(bindTo);
      case SproutPreviewIf(:final condition, :final thenActions, :final elseActions):
        if (_evaluateCondition(condition)) {
          for (final a in thenActions) {
            _runAction(a);
          }
        } else if (elseActions != null) {
          for (final a in elseActions) {
            _runAction(a);
          }
        }
        return null;
      case SproutPreviewLoop(:final variable, :final range, :final body):
        final parts = range.split('..');
        if (parts.length == 2) {
          final start = int.tryParse(parts[0]) ?? 0;
          final end = int.tryParse(parts[1]) ?? 0;
          for (var i = start; i <= end && i < start + 100; i++) {
            _state[variable] = i;
            for (final a in body) {
              _runAction(a);
            }
          }
        }
        return null;
      case SproutPreviewScheduleReminder(:final message, :final time):
        return SproutPreviewReminderRequest(
          message: _resolveExpression(message),
          time: _resolveExpression(time),
        );
    }
  }

  String _resolveExpression(String expression) {
    final trimmed = expression.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      return resolveTemplate(trimmed.substring(1, trimmed.length - 1));
    }
    final value = _state[trimmed];
    if (value is List<String>) return value.join(', ');
    return value?.toString() ?? trimmed;
  }

  static SproutPreviewScreen _parseScreen(
    String name,
    String body,
    Map<String, Object?> state,
  ) {
    final stateRegex = RegExp(
      r'^\s*state\s+(\w+)\s*(?::|=)\s*(.+?)\s*$',
      multiLine: true,
    );
    for (final match in stateRegex.allMatches(body)) {
      final name = match.group(1)!;
      final value = match.group(2)!.trim();
      state[name] = _parseStateValue(value);
    }

    final uiBody = _extractKeywordBlock(body, 'ui') ?? '';
    return SproutPreviewScreen(
      name: name,
      elements: _parseElements(uiBody),
    );
  }

  static Object? _parseStateValue(String value) {
    if (value == '[]') return <Object?>[];
    if (value == 'true') return true;
    if (value == 'false') return false;
    final integer = int.tryParse(value);
    if (integer != null) return integer;
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  static List<SproutPreviewElement> _parseElements(String source) {
    final elements = <SproutPreviewElement>[];
    final lines = source.split('\n');
    final label = RegExp(r'^(?:label|title)\s+"([^"]*)"$');
    final legacyLabel = RegExp(r'^(?:label|title)\("([^"]*)"\)$');
    final input = RegExp(r'^input\s+"([^"]+)"\s*->\s*(\w+)$');
    final textArea = RegExp(r'^textarea\s+"([^"]+)"\s*->\s*(\w+)$');
    final number = RegExp(r'^number\s+"([^"]+)"\s*->\s*(\w+)$');
    final choice = RegExp(r'^choice\s+"([^"]+)"\s+\[([^\]]+)\]\s*->\s*(\w+)$');
    final progress = RegExp(r'^progress\s+"([^"]+)"\s+(\w+)\s*/\s*(\w+)$');
    final list = RegExp(r'^list\s+(\w+)$');
    final records = RegExp(
      r'^records\s+(\w+)\s+\[([^\]]+)\](?:\s+search\s+(\w+))?(?:\s+filter\s+(\w+))?(?:\s+(editable))?$',
    );
    final breakdown = RegExp(
      r'^breakdown\s+"([^"]+)"\s+(\w+)\s+(\w+)\s+\[([^\]]+)\]$',
    );
    final aggregate = RegExp(
      r'^aggregate\s+"([^"]+)"\s+(\w+)\s+(\w+)\s+\[([^\]]+)\]\s*-\s*\[([^\]]+)\]$',
    );
    final section = RegExp(r'^section\s+"([^"]+)"(?:\s+"([^"]*)")?$');
    final metric = RegExp(r'^metric\s+"([^"]+)"\s*->\s*(\w+)$');
    final toggle = RegExp(r'^toggle\s+"([^"]+)"\s*->\s*(\w+)$');
    final chart = RegExp(r'^chart\s+"([^"]+)"\s+(\w+)\s+(\w+)\s+by\s+(\w+)$');
    final audio = RegExp(r'^audio\s+"([^"]+)"\s*->\s*(\w+)$');
    final camera = RegExp(r'^camera\s+"([^"]+)"\s*->\s*(\w+)$');
    final button = RegExp(r'^button\s+"([^"]+)"\s*(.*)$');
    final legacyButton = RegExp(r'^button\("([^"]+)"\)$');

    var index = 0;
    while (index < lines.length) {
      final line = lines[index].trim();
      index++;
      if (line.isEmpty ||
          line.startsWith('//') ||
          line == '}' ||
          line == 'column {' ||
          line == 'row {') {
        continue;
      }

      final textMatch = label.firstMatch(line) ?? legacyLabel.firstMatch(line);
      if (textMatch != null) {
        elements.add(SproutPreviewLabel(textMatch.group(1)!));
        continue;
      }
      final inputMatch = input.firstMatch(line);
      if (inputMatch != null) {
        elements.add(
          SproutPreviewInput(
            placeholder: inputMatch.group(1)!,
            binding: inputMatch.group(2)!,
          ),
        );
        continue;
      }
      final textAreaMatch = textArea.firstMatch(line);
      if (textAreaMatch != null) {
        elements.add(SproutPreviewTextArea(
          placeholder: textAreaMatch.group(1)!,
          binding: textAreaMatch.group(2)!,
        ));
        continue;
      }
      final numberMatch = number.firstMatch(line);
      if (numberMatch != null) {
        elements.add(SproutPreviewNumberInput(
          placeholder: numberMatch.group(1)!,
          binding: numberMatch.group(2)!,
        ));
        continue;
      }
      final choiceMatch = choice.firstMatch(line);
      if (choiceMatch != null) {
        final options = choiceMatch
            .group(2)!
            .split(',')
            .map((option) => option.trim().replaceAll('"', ''))
            .where((option) => option.isNotEmpty)
            .toList(growable: false);
        elements.add(SproutPreviewChoice(
          label: choiceMatch.group(1)!,
          options: options,
          binding: choiceMatch.group(3)!,
        ));
        continue;
      }
      final progressMatch = progress.firstMatch(line);
      if (progressMatch != null) {
        elements.add(SproutPreviewProgress(
          label: progressMatch.group(1)!,
          valueBinding: progressMatch.group(2)!,
          totalBinding: progressMatch.group(3)!,
        ));
        continue;
      }
      final recordsMatch = records.firstMatch(line);
      if (recordsMatch != null) {
        elements.add(SproutPreviewRecordList(
          binding: recordsMatch.group(1)!,
          fields: recordsMatch
              .group(2)!
              .split(',')
              .map((field) => field.trim())
              .where((field) => field.isNotEmpty)
              .toList(growable: false),
          searchBinding: recordsMatch.group(3),
          filterBinding: recordsMatch.group(4),
          editable: recordsMatch.group(5) != null,
        ));
        continue;
      }
      final breakdownMatch = breakdown.firstMatch(line);
      if (breakdownMatch != null) {
        elements.add(SproutPreviewBreakdown(
          label: breakdownMatch.group(1)!,
          collection: breakdownMatch.group(2)!,
          amountField: breakdownMatch.group(3)!,
          kinds: breakdownMatch
              .group(4)!
              .split(',')
              .map((kind) => kind.trim().replaceAll('"', ''))
              .where((kind) => kind.isNotEmpty)
              .toList(growable: false),
        ));
        continue;
      }
      final aggregateMatch = aggregate.firstMatch(line);
      if (aggregateMatch != null) {
        List<String> kinds(int group) => aggregateMatch
            .group(group)!
            .split(',')
            .map((kind) => kind.trim().replaceAll('"', ''))
            .where((kind) => kind.isNotEmpty)
            .toList(growable: false);
        elements.add(SproutPreviewAggregate(
          label: aggregateMatch.group(1)!,
          collection: aggregateMatch.group(2)!,
          amountField: aggregateMatch.group(3)!,
          positiveKinds: kinds(4),
          negativeKinds: kinds(5),
        ));
        continue;
      }
      final listMatch = list.firstMatch(line);
      if (listMatch != null) {
        elements.add(SproutPreviewList(listMatch.group(1)!));
        continue;
      }
      final sectionMatch = section.firstMatch(line);
      if (sectionMatch != null) {
        elements.add(SproutPreviewSection(
          title: sectionMatch.group(1)!,
          detail: sectionMatch.group(2),
        ));
        continue;
      }
      final metricMatch = metric.firstMatch(line);
      if (metricMatch != null) {
        elements.add(
            SproutPreviewMetric(metricMatch.group(1)!, metricMatch.group(2)!));
        continue;
      }
      final toggleMatch = toggle.firstMatch(line);
      if (toggleMatch != null) {
        elements.add(
            SproutPreviewToggle(toggleMatch.group(1)!, toggleMatch.group(2)!));
        continue;
      }
      final chartMatch = chart.firstMatch(line);
      if (chartMatch != null) {
        elements.add(SproutPreviewChart(
          title: chartMatch.group(1)!,
          collection: chartMatch.group(2)!,
          amountField: chartMatch.group(3)!,
          chartType: chartMatch.group(4)!,
        ));
        continue;
      }
      final audioMatch = audio.firstMatch(line);
      if (audioMatch != null) {
        elements.add(SproutPreviewAudioPlayer(
          label: audioMatch.group(1)!,
          source: audioMatch.group(2)!,
        ));
        continue;
      }
      final cameraMatch = camera.firstMatch(line);
      if (cameraMatch != null) {
        elements.add(SproutPreviewCamera(
          label: cameraMatch.group(1)!,
          binding: cameraMatch.group(2)!,
        ));
        continue;
      }
      if (line == 'divider') {
        elements.add(const SproutPreviewDivider());
        continue;
      }
      final oldButton = legacyButton.firstMatch(line);
      if (oldButton != null) {
        elements.add(SproutPreviewButton(oldButton.group(1)!, const []));
        continue;
      }
      final buttonMatch = button.firstMatch(line);
      if (buttonMatch != null) {
        final title = buttonMatch.group(1)!;
        final remainder = buttonMatch.group(2)!.trim();
        if (remainder.startsWith('->')) {
          elements.add(
            SproutPreviewButton(
              title,
              [SproutPreviewNavigate(remainder.substring(2).trim())],
            ),
          );
          continue;
        }
        if (remainder.startsWith('{')) {
          var actionSource = remainder.substring(1);
          var depth = _braceDelta(remainder);
          while (depth > 0 && index < lines.length) {
            final next = lines[index++];
            depth += _braceDelta(next);
            actionSource = '$actionSource\n$next';
          }
          final closing = actionSource.lastIndexOf('}');
          if (closing >= 0) actionSource = actionSource.substring(0, closing);
          elements.add(SproutPreviewButton(title, _parseActions(actionSource)));
          continue;
        }
        elements.add(SproutPreviewButton(title, const []));
      }
    }
    return elements;
  }

  static List<SproutPreviewAction> _parseActions(String source) {
    final actions = <SproutPreviewAction>[];
    
    // Handle nested blocks first
    final ifRegex = RegExp(r'^if\s+(.+?)\s*\{');
    final loopRegex = RegExp(r'^for\s+(\w+)\s+in\s+(.+?)\s*\{');

    final append = RegExp(r'^(\w+)\.append\((.+)\)$');
    final record = RegExp(r'^(\w+)\.add\((.+)\)$');
    final remove = RegExp(r'^(\w+)\.remove\((.+)\)$');
    final removeFirst = RegExp(r'^(\w+)\.remove_first\(\)$');
    final reminder = RegExp(r'^reminder\s+(.+?)\s+at\s+(.+)$');
    final increment = RegExp(r'^increment\s+(\w+)(?:\s+by\s+(-?\d+))?$');
    final clear = RegExp(r'^clear\s+(\w+)$');
    final fetch = RegExp(r'^fetch\s+"([^"]+)"\s*->\s*(\w+)$');
    final scan = RegExp(r'^scan\s*->\s*(\w+)$');
    final assignment = RegExp(r'^(\w+)\s*=\s*(.+)$');
    final navigate = RegExp(r'^(?:go|navigate)\s+(\w+)$');

    final lines = source.split(RegExp(r'[\n;]'));

    var index = 0;
    while (index < lines.length) {
      final value = lines[index].trim();
      index++;
      if (value.isEmpty || value.startsWith('//')) continue;

      final ifMatch = ifRegex.firstMatch(value);
      if (ifMatch != null) {
        final condition = ifMatch.group(1)!.trim();
        var blockSource = '';
        var depth = 1;
        
        final remainder = value.substring(ifMatch.end).trim();
        if (remainder.isNotEmpty) {
          blockSource = remainder;
          depth += _braceDelta(remainder);
        }

        List<SproutPreviewAction>? elseActions;
        while (depth > 0 && index < lines.length) {
          final next = lines[index++].trim();
          if (next.isEmpty || next.startsWith('//')) continue;
          
          if (depth == 1 && next.contains('else') && next.contains('}')) {
            final closingIdx = next.indexOf('}');
            final ifPart = next.substring(0, closingIdx).trim();
            if (ifPart.isNotEmpty) {
              blockSource = blockSource.isEmpty ? ifPart : '$blockSource\n$ifPart';
            }
            
            var elseSource = next.substring(closingIdx + 1).trim();
            var elseDepth = 1;
            final elseRemainder = elseSource.contains('{') ? elseSource.substring(elseSource.indexOf('{') + 1).trim() : elseSource;
            elseSource = elseRemainder;
            if (elseSource.isNotEmpty) {
              elseDepth += _braceDelta(elseSource);
            }

            while (elseDepth > 0 && index < lines.length) {
              final subNext = lines[index++].trim();
              if (subNext.isEmpty || subNext.startsWith('//')) continue;

              final delta = _braceDelta(subNext);
              if (elseDepth == 1 && (delta < 0 || subNext.startsWith('}'))) {
                break;
              }
              elseDepth += delta;
              elseSource = elseSource.isEmpty ? subNext : '$elseSource\n$subNext';
            }
            elseActions = _parseActions(elseSource);
            break;
          }
          
          final delta = _braceDelta(next);
          if (depth == 1 && (delta < 0 || next.startsWith('}'))) {
            break;
          }
          depth += delta;
          blockSource = blockSource.isEmpty ? next : '$blockSource\n$next';
        }
        
        final thenActions = _parseActions(blockSource);

        if (elseActions == null && index < lines.length) {
          var peekIndex = index;
          while (peekIndex < lines.length && lines[peekIndex].trim().isEmpty) {
            peekIndex++;
          }
          if (peekIndex < lines.length) {
            final peekLine = lines[peekIndex].trim();
            if (peekLine.startsWith('else') || peekLine.contains('else')) {
              index = peekIndex + 1;
              var elseSource = '';
              var elseDepth = 1;
              
              final elseRemainder = peekLine.contains('{') ? peekLine.substring(peekLine.indexOf('{') + 1).trim() : '';
              if (elseRemainder.isNotEmpty) {
                elseSource = elseRemainder;
                elseDepth += _braceDelta(elseRemainder);
              }

              while (elseDepth > 0 && index < lines.length) {
                final subNext = lines[index++].trim();
                if (subNext.isEmpty || subNext.startsWith('//')) continue;

                final delta = _braceDelta(subNext);
                if (elseDepth == 1 && (delta < 0 || subNext.startsWith('}'))) {
                  break;
                }
                elseDepth += delta;
                elseSource = elseSource.isEmpty ? subNext : '$elseSource\n$subNext';
              }
              elseActions = _parseActions(elseSource);
            }
          }
        }

        actions.add(SproutPreviewIf(condition, thenActions, elseActions));
        continue;
      }

      final loopMatch = loopRegex.firstMatch(value);
      if (loopMatch != null) {
        final variable = loopMatch.group(1)!;
        final range = loopMatch.group(2)!;
        var blockSource = value.substring(loopMatch.end);
        var depth = _braceDelta(value);
        while (depth > 0 && index < lines.length) {
          final next = lines[index++];
          depth += _braceDelta(next);
          blockSource = '$blockSource\n$next';
        }
        final closing = blockSource.lastIndexOf('}');
        if (closing >= 0) blockSource = blockSource.substring(0, closing);
        
        actions.add(SproutPreviewLoop(variable, range, _parseActions(blockSource)));
        continue;
      }

      final recordMatch = record.firstMatch(value);
      if (recordMatch != null) {
        final fields = <String, String>{};
        for (final field in recordMatch.group(2)!.split(',')) {
          final parts = field.split(':');
          if (parts.length == 2 && parts.first.trim().isNotEmpty) {
            fields[parts.first.trim()] = parts.last.trim();
          }
        }
        actions.add(SproutPreviewAppendRecord(
          recordMatch.group(1)!,
          fields,
        ));
        continue;
      }
      final appendMatch = append.firstMatch(value);
      final removeMatch = remove.firstMatch(value);
      final removeFirstMatch = removeFirst.firstMatch(value);
      final reminderMatch = reminder.firstMatch(value);
      final incrementMatch = increment.firstMatch(value);
      final clearMatch = clear.firstMatch(value);
      final assignmentMatch = assignment.firstMatch(value);
      final navigateMatch = navigate.firstMatch(value);
      if (appendMatch != null) {
        actions.add(
            SproutPreviewAppend(appendMatch.group(1)!, appendMatch.group(2)!));
      } else if (removeMatch != null) {
        actions.add(
            SproutPreviewRemove(removeMatch.group(1)!, removeMatch.group(2)!));
      } else if (removeFirstMatch != null) {
        actions.add(SproutPreviewRemoveFirst(removeFirstMatch.group(1)!));
      } else if (reminderMatch != null) {
        actions.add(SproutPreviewScheduleReminder(
          reminderMatch.group(1)!.trim(),
          reminderMatch.group(2)!.trim(),
        ));
      } else if (incrementMatch != null) {
        actions.add(SproutPreviewIncrement(
          incrementMatch.group(1)!,
          int.tryParse(incrementMatch.group(2) ?? '') ?? 1,
        ));
      } else if (clearMatch != null) {
        actions.add(SproutPreviewClear(clearMatch.group(1)!));
      } else if (fetch.firstMatch(value) != null) {
        final match = fetch.firstMatch(value)!;
        actions.add(SproutPreviewFetch(match.group(1)!, match.group(2)!));
      } else if (scan.firstMatch(value) != null) {
        final match = scan.firstMatch(value)!;
        actions.add(SproutPreviewScan(match.group(1)!));
      } else if (navigateMatch != null) {
        actions.add(SproutPreviewNavigate(navigateMatch.group(1)!));
      } else if (assignmentMatch != null) {
        actions.add(SproutPreviewUpdate(
          assignmentMatch.group(1)!,
          assignmentMatch.group(2)!,
        ));
      }
    }
    return actions;
  }

  static List<_NamedBlock> _extractNamedBlocks(String source, String keyword) {
    final matcher = RegExp('$keyword\\s+(\\w+)\\s*\\{');
    final blocks = <_NamedBlock>[];
    for (final match in matcher.allMatches(source)) {
      final name = match.group(1)!;
      final opening = source.indexOf('{', match.start);
      final closing = _matchingBrace(source, opening);
      if (closing != null) {
        blocks.add(_NamedBlock(name, source.substring(opening + 1, closing)));
      }
    }
    return blocks;
  }

  static String? _extractKeywordBlock(String source, String keyword) {
    final match = RegExp('$keyword\\s*\\{').firstMatch(source);
    if (match == null) return null;
    final opening = source.indexOf('{', match.start);
    final closing = _matchingBrace(source, opening);
    return closing == null ? null : source.substring(opening + 1, closing);
  }

  static int? _matchingBrace(String source, int opening) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var index = opening; index < source.length; index++) {
      final character = source[index];
      if (character == '\\' && inString && !escaped) {
        escaped = true;
        continue;
      }
      if (character == '"' && !escaped) inString = !inString;
      if (!inString && character == '{') depth++;
      if (!inString && character == '}') {
        depth--;
        if (depth == 0) return index;
      }
      escaped = false;
    }
    return null;
  }

  static int _braceDelta(String source) {
    var depth = 0;
    for (final character in source.runes) {
      if (character == 123) depth++;
      if (character == 125) depth--;
    }
    return depth;
  }
}

class SproutPreviewScreen {
  final String name;
  final List<SproutPreviewElement> elements;

  const SproutPreviewScreen({required this.name, required this.elements});
}

sealed class SproutPreviewElement {
  const SproutPreviewElement();
}

class SproutPreviewLabel extends SproutPreviewElement {
  final String text;

  const SproutPreviewLabel(this.text);
}

class SproutPreviewInput extends SproutPreviewElement {
  final String placeholder;
  final String binding;

  const SproutPreviewInput({required this.placeholder, required this.binding});
}

class SproutPreviewTextArea extends SproutPreviewElement {
  final String placeholder;
  final String binding;

  const SproutPreviewTextArea(
      {required this.placeholder, required this.binding});
}

class SproutPreviewNumberInput extends SproutPreviewElement {
  final String placeholder;
  final String binding;

  const SproutPreviewNumberInput({
    required this.placeholder,
    required this.binding,
  });
}

class SproutPreviewChoice extends SproutPreviewElement {
  final String label;
  final List<String> options;
  final String binding;

  const SproutPreviewChoice({
    required this.label,
    required this.options,
    required this.binding,
  });
}

class SproutPreviewProgress extends SproutPreviewElement {
  final String label;
  final String valueBinding;
  final String totalBinding;

  const SproutPreviewProgress({
    required this.label,
    required this.valueBinding,
    required this.totalBinding,
  });
}

class SproutPreviewRecordEntry {
  final int index;
  final Map<String, Object?> record;

  const SproutPreviewRecordEntry(this.index, this.record);
}

class SproutPreviewRecordList extends SproutPreviewElement {
  final String binding;
  final List<String> fields;
  final String? searchBinding;
  final String? filterBinding;
  final bool editable;

  const SproutPreviewRecordList({
    required this.binding,
    required this.fields,
    this.searchBinding,
    this.filterBinding,
    this.editable = false,
  });
}

class SproutPreviewBreakdown extends SproutPreviewElement {
  final String label;
  final String collection;
  final String amountField;
  final List<String> kinds;

  const SproutPreviewBreakdown({
    required this.label,
    required this.collection,
    required this.amountField,
    required this.kinds,
  });
}

class SproutPreviewAggregate extends SproutPreviewElement {
  final String label;
  final String collection;
  final String amountField;
  final List<String> positiveKinds;
  final List<String> negativeKinds;

  const SproutPreviewAggregate({
    required this.label,
    required this.collection,
    required this.amountField,
    required this.positiveKinds,
    required this.negativeKinds,
  });
}

class SproutPreviewList extends SproutPreviewElement {
  final String binding;

  const SproutPreviewList(this.binding);
}

class SproutPreviewSection extends SproutPreviewElement {
  final String title;
  final String? detail;

  const SproutPreviewSection({required this.title, this.detail});
}

class SproutPreviewMetric extends SproutPreviewElement {
  final String label;
  final String binding;

  const SproutPreviewMetric(this.label, this.binding);
}

class SproutPreviewToggle extends SproutPreviewElement {
  final String label;
  final String binding;

  const SproutPreviewToggle(this.label, this.binding);
}

class SproutPreviewChart extends SproutPreviewElement {
  final String title;
  final String collection;
  final String amountField;
  final String chartType;

  const SproutPreviewChart({
    required this.title,
    required this.collection,
    required this.amountField,
    required this.chartType,
  });
}

class SproutPreviewAudioPlayer extends SproutPreviewElement {
  final String label;
  final String source;

  const SproutPreviewAudioPlayer({
    required this.label,
    required this.source,
  });
}

class SproutPreviewCamera extends SproutPreviewElement {
  final String label;
  final String binding;

  const SproutPreviewCamera({
    required this.label,
    required this.binding,
  });
}

class SproutPreviewDivider extends SproutPreviewElement {
  const SproutPreviewDivider();
}

class SproutPreviewButton extends SproutPreviewElement {
  final String label;
  final List<SproutPreviewAction> actions;

  const SproutPreviewButton(this.label, this.actions);
}

sealed class SproutPreviewAction {
  const SproutPreviewAction();
}

class SproutPreviewNavigate extends SproutPreviewAction {
  final String target;

  const SproutPreviewNavigate(this.target);
}

class SproutPreviewUpdate extends SproutPreviewAction {
  final String variable;
  final String expression;

  const SproutPreviewUpdate(this.variable, this.expression);
}

class SproutPreviewAppend extends SproutPreviewAction {
  final String variable;
  final String expression;

  const SproutPreviewAppend(this.variable, this.expression);
}

class SproutPreviewAppendRecord extends SproutPreviewAction {
  final String variable;
  final Map<String, String> fields;

  const SproutPreviewAppendRecord(this.variable, this.fields);
}

class SproutPreviewRemove extends SproutPreviewAction {
  final String variable;
  final String expression;

  const SproutPreviewRemove(this.variable, this.expression);
}

class SproutPreviewRemoveFirst extends SproutPreviewAction {
  final String variable;

  const SproutPreviewRemoveFirst(this.variable);
}

class SproutPreviewScheduleReminder extends SproutPreviewAction {
  final String message;
  final String time;

  const SproutPreviewScheduleReminder(this.message, this.time);
}

class SproutPreviewIncrement extends SproutPreviewAction {
  final String variable;
  final int by;

  const SproutPreviewIncrement(this.variable, this.by);
}

class SproutPreviewClear extends SproutPreviewAction {
  final String variable;

  const SproutPreviewClear(this.variable);
}

class SproutPreviewFetch extends SproutPreviewAction {
  final String url;
  final String bindTo;

  const SproutPreviewFetch(this.url, this.bindTo);
}

class SproutPreviewScan extends SproutPreviewAction {
  final String bindTo;

  const SproutPreviewScan(this.bindTo);
}

class SproutPreviewIf extends SproutPreviewAction {
  final String condition;
  final List<SproutPreviewAction> thenActions;
  final List<SproutPreviewAction>? elseActions;

  const SproutPreviewIf(this.condition, this.thenActions, [this.elseActions]);
}

class SproutPreviewLoop extends SproutPreviewAction {
  final String variable;
  final String range;
  final List<SproutPreviewAction> body;

  const SproutPreviewLoop(this.variable, this.range, this.body);
}

sealed class SproutPreviewEffect {
  const SproutPreviewEffect();
}

class SproutPreviewReminderRequest extends SproutPreviewEffect {
  final String message;
  final String time;

  const SproutPreviewReminderRequest(
      {required this.message, required this.time});
}

class SproutPreviewScanRequest extends SproutPreviewEffect {
  final String binding;

  const SproutPreviewScanRequest(this.binding);
}

class SproutPreviewPhotoRequest extends SproutPreviewEffect {
  final String binding;

  const SproutPreviewPhotoRequest(this.binding);
}

class _NamedBlock {
  final String name;
  final String body;

  const _NamedBlock(this.name, this.body);
}
