import 'dart:async';
import 'dart:collection';
import 'debugger.dart';

class ReactiveRuntime {
  static final ReactiveRuntime _instance = ReactiveRuntime._internal();
  factory ReactiveRuntime() => _instance;
  ReactiveRuntime._internal();

  final Map<String, ReactiveValue> _values = {};
  final Map<String, Set<Function>> _watchers = {};
  final SproutDebugger _debugger = SproutDebugger();
  
  bool _isDisposed = false;
  Timer? _batchUpdateTimer;
  final Set<String> _pendingUpdates = {};

  // Get a reactive value by key
  T getValue<T>(String key, T defaultValue) {
    if (_isDisposed) return defaultValue;
    
    final reactiveValue = _values[key];
    if (reactiveValue != null && reactiveValue.value is T) {
      return reactiveValue.value as T;
    }
    
    // Create new reactive value if it doesn't exist
    _values[key] = ReactiveValue<T>(defaultValue);
    _debugger.debug('Created reactive value: $key = $defaultValue');
    
    return defaultValue;
  }

  // Set a reactive value and trigger watchers
  void setValue<T>(String key, T value) {
    if (_isDisposed) return;
    
    final oldValue = _values[key]?.value;
    
    // Only update if value actually changed
    if (oldValue != value) {
      _values[key] = ReactiveValue<T>(value);
      _debugger.debug('Updated reactive value: $key = $value (was $oldValue)');
      
      // Schedule batch update
      _scheduleBatchUpdate(key);
    }
  }

  // Watch for changes to a reactive value
  void watch(String key, Function(dynamic) callback) {
    if (_isDisposed) return;
    
    _watchers.putIfAbsent(key, () => {}).add(callback);
    _debugger.debug('Added watcher for: $key');
  }

  // Remove a watcher
  void unwatch(String key, Function(dynamic) callback) {
    final watchers = _watchers[key];
    if (watchers != null) {
      watchers.remove(callback);
      if (watchers.isEmpty) {
        _watchers.remove(key);
      }
      _debugger.debug('Removed watcher for: $key');
    }
  }

  // Batch update mechanism to avoid excessive notifications
  void _scheduleBatchUpdate(String key) {
    _pendingUpdates.add(key);
    
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(const Duration(milliseconds: 16), () { // ~60fps
      _processBatchUpdates();
    });
  }

  void _processBatchUpdates() {
    if (_isDisposed || _pendingUpdates.isEmpty) return;
    
    final updates = List<String>.from(_pendingUpdates);
    _pendingUpdates.clear();
    
    for (final key in updates) {
      final watchers = _watchers[key];
      if (watchers != null && watchers.isNotEmpty) {
        final value = _values[key]?.value;
        
        // Notify all watchers
        for (final callback in List.from(watchers)) {
          try {
            callback(value);
          } catch (e, stack) {
            _debugger.error('Error in watcher for $key: $e', stack: stack);
          }
        }
        
        _debugger.debug('Notified ${watchers.length} watchers for: $key');
      }
    }
  }

  // Computed values that automatically update when dependencies change
  void computed<T>(String key, T Function() computation, List<String> dependencies) {
    if (_isDisposed) return;
    
    // Initial computation
    try {
      final value = computation();
      setValue(key, value);
    } catch (e, stack) {
      _debugger.error('Error computing $key: $e', stack: stack);
      return;
    }
    
    // Watch all dependencies
    for (final dependency in dependencies) {
      watch(dependency, (_) {
        try {
          final newValue = computation();
          setValue(key, newValue);
        } catch (e, stack) {
          _debugger.error('Error recomputing $key: $e', stack: stack);
        }
      });
    }
    
    _debugger.debug('Created computed value: $key (depends on ${dependencies.join(', ')})');
  }

  // Execute a transaction where multiple updates are batched
  void transaction(VoidCallback updates) {
    if (_isDisposed) return;
    
    _batchUpdateTimer?.cancel();
    
    try {
      updates();
    } finally {
      // Process all pending updates at once
      _processBatchUpdates();
    }
  }

  // Debug methods
  Map<String, dynamic> getState() {
    return Map.fromEntries(
      _values.entries.map((e) => MapEntry(e.key, e.value.value))
    );
  }

  List<String> getWatchedKeys() {
    return _watchers.keys.toList();
  }

  int getWatcherCount(String key) {
    return _watchers[key]?.length ?? 0;
  }

  // Clear all reactive state
  void clear() {
    _batchUpdateTimer?.cancel();
    _pendingUpdates.clear();
    _values.clear();
    _watchers.clear();
    _debugger.info('Cleared all reactive state');
  }

  // Dispose of the runtime
  void dispose() {
    if (_isDisposed) return;
    
    _batchUpdateTimer?.cancel();
    _pendingUpdates.clear();
    _values.clear();
    _watchers.clear();
    _isDisposed = true;
    
    _debugger.info('Reactive runtime disposed');
  }

  // Performance monitoring
  RuntimeStats getStats() {
    return RuntimeStats(
      valueCount: _values.length,
      watcherCount: _watchers.values.map((w) => w.length).fold(0, (a, b) => a + b),
      pendingUpdates: _pendingUpdates.length,
      isDisposed: _isDisposed,
    );
  }
}

class ReactiveValue<T> {
  final T value;
  final DateTime lastUpdated;

  ReactiveValue(this.value) : lastUpdated = DateTime.now();

  @override
  String toString() => 'ReactiveValue($value)';
}

class RuntimeStats {
  final int valueCount;
  final int watcherCount;
  final int pendingUpdates;
  final bool isDisposed;

  const RuntimeStats({
    required this.valueCount,
    required this.watcherCount,
    required this.pendingUpdates,
    required this.isDisposed,
  });

  @override
  String toString() {
    return 'RuntimeStats(values: $valueCount, watchers: $watcherCount, pending: $pendingUpdates, disposed: $isDisposed)';
  }
}

// Utility classes for reactive programming
class ReactiveList<T> {
  final ReactiveRuntime _runtime = ReactiveRuntime();
  final String _key;
  List<T> _items = [];

  ReactiveList(this._key, [List<T>? initialItems]) {
    if (initialItems != null) {
      _items = List.from(initialItems);
      _runtime.setValue(_key, _items);
    }
  }

  List<T> get items => List.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  void add(T item) {
    _items.add(item);
    _runtime.setValue(_key, _items);
  }

  void addAll(Iterable<T> items) {
    _items.addAll(items);
    _runtime.setValue(_key, _items);
  }

  bool remove(T item) {
    final removed = _items.remove(item);
    if (removed) {
      _runtime.setValue(_key, _items);
    }
    return removed;
  }

  T removeAt(int index) {
    final item = _items.removeAt(index);
    _runtime.setValue(_key, _items);
    return item;
  }

  void clear() {
    _items.clear();
    _runtime.setValue(_key, _items);
  }

  void insert(int index, T item) {
    _items.insert(index, item);
    _runtime.setValue(_key, _items);
  }

  void watch(Function(List<T>) callback) {
    _runtime.watch(_key, (value) {
      if (value is List<T>) {
        callback(value);
      }
    });
  }

  T operator [](int index) => _items[index];
  
  void operator []=(int index, T value) {
    _items[index] = value;
    _runtime.setValue(_key, _items);
  }
}

class ReactiveMap<K, V> {
  final ReactiveRuntime _runtime = ReactiveRuntime();
  final String _key;
  Map<K, V> _map = {};

  ReactiveMap(this._key, [Map<K, V>? initialMap]) {
    if (initialMap != null) {
      _map = Map.from(initialMap);
      _runtime.setValue(_key, _map);
    }
  }

  Map<K, V> get map => Map.unmodifiable(_map);
  int get length => _map.length;
  bool get isEmpty => _map.isEmpty;
  bool get isNotEmpty => _map.isNotEmpty;
  Iterable<K> get keys => _map.keys;
  Iterable<V> get values => _map.values;

  V? operator [](K key) => _map[key];

  void operator []=(K key, V value) {
    _map[key] = value;
    _runtime.setValue(_key, _map);
  }

  V? remove(K key) {
    final value = _map.remove(key);
    if (value != null) {
      _runtime.setValue(_key, _map);
    }
    return value;
  }

  void clear() {
    _map.clear();
    _runtime.setValue(_key, _map);
  }

  bool containsKey(K key) => _map.containsKey(key);
  bool containsValue(V value) => _map.containsValue(value);

  void addAll(Map<K, V> other) {
    _map.addAll(other);
    _runtime.setValue(_key, _map);
  }

  void watch(Function(Map<K, V>) callback) {
    _runtime.watch(_key, (value) {
      if (value is Map<K, V>) {
        callback(value);
      }
    });
  }
}
