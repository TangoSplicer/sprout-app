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

  String inputValue(String binding) => (_state[binding] as String?) ?? '';

  List<String> listValue(String binding) {
    final value = _state[binding];
    if (value is List<String>) return List.unmodifiable(value);
    return const [];
  }

  void updateInput(String binding, String value) {
    _state[binding] = value.length > 1000 ? value.substring(0, 1000) : value;
  }

  void activate(SproutPreviewButton button) {
    for (final action in button.actions) {
      _runAction(action);
    }
  }

  String resolveTemplate(String value) {
    return value.replaceAllMapped(RegExp(r'\$\{([^}]+)\}'), (match) {
      final stateValue = _state[match.group(1)!.trim()];
      if (stateValue is List<String>) return stateValue.join(', ');
      return stateValue?.toString() ?? '';
    });
  }

  void _runAction(SproutPreviewAction action) {
    switch (action) {
      case SproutPreviewNavigate(:final target):
        if (target == 'Back') {
          if (_navigationStack.length > 1) _navigationStack.removeLast();
        } else if (_screens.containsKey(target)) {
          _navigationStack.add(target);
        }
      case SproutPreviewUpdate(:final variable, :final expression):
        _state[variable] = _resolveExpression(expression);
      case SproutPreviewAppend(:final variable, :final expression):
        final values = List<String>.from(listValue(variable));
        if (values.length < 100) values.add(_resolveExpression(expression));
        _state[variable] = values;
      case SproutPreviewRemove(:final variable, :final expression):
        final values = List<String>.from(listValue(variable));
        values.remove(_resolveExpression(expression));
        _state[variable] = values;
      case SproutPreviewRemoveFirst(:final variable):
        final values = List<String>.from(listValue(variable));
        if (values.isNotEmpty) values.removeAt(0);
        _state[variable] = values;
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
      r'^\s*state\s+(\w+)\s*:\s*(.+?)\s*$',
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
    if (value == '[]') return <String>[];
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
    final list = RegExp(r'^list\s+(\w+)$');
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
      final listMatch = list.firstMatch(line);
      if (listMatch != null) {
        elements.add(SproutPreviewList(listMatch.group(1)!));
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
    final append = RegExp(r'^(\w+)\.append\((.+)\)$');
    final remove = RegExp(r'^(\w+)\.remove\((.+)\)$');
    final removeFirst = RegExp(r'^(\w+)\.remove_first\(\)$');
    final assignment = RegExp(r'^(\w+)\s*=\s*(.+)$');
    final navigate = RegExp(r'^(?:go|navigate)\s+(\w+)$');

    for (final statement in source.split(RegExp(r'[\n;]'))) {
      final value = statement.trim().replaceAll('}', '');
      if (value.isEmpty || value.startsWith('//')) continue;
      final appendMatch = append.firstMatch(value);
      final removeMatch = remove.firstMatch(value);
      final removeFirstMatch = removeFirst.firstMatch(value);
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

class SproutPreviewList extends SproutPreviewElement {
  final String binding;

  const SproutPreviewList(this.binding);
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

class SproutPreviewRemove extends SproutPreviewAction {
  final String variable;
  final String expression;

  const SproutPreviewRemove(this.variable, this.expression);
}

class SproutPreviewRemoveFirst extends SproutPreviewAction {
  final String variable;

  const SproutPreviewRemoveFirst(this.variable);
}

class _NamedBlock {
  final String name;
  final String body;

  const _NamedBlock(this.name, this.body);
}
