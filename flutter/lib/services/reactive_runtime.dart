// flutter/lib/services/reactive_runtime.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:wasm3/wasm3.dart';

/// A reactive runtime for Sprout apps
/// Manages state and WASM execution
class ReactiveRuntime extends ChangeNotifier {
  /// The WASM runtime instance
  Wasm3? _runtime;
  
  /// The WASM module
  WasmModule? _module;
  
  /// The WASM memory
  ByteBuffer? _memory;
  
  /// The current state of the app
  Map<String, dynamic> _state = {};
  
  /// Get the current state
  Map<String, dynamic> get state => _state;
  
  /// Get the WASM memory
  ByteBuffer? get memory => _memory;
  
  /// Load a WASM module and initialize the runtime
  Future<void> load(Uint8List wasm, {Map<String, dynamic>? initialState}) async {
    try {
      // Initialize the WASM runtime
      _runtime = Wasm3();
      _module = await _runtime!.loadModule(wasm);
      
      // Get the memory
      _memory = _module!.memory;
      
      // Initialize state
      if (initialState != null) {
        _state = Map.from(initialState);
      }
      
      // Set up state bindings
      _setupStateBindings();
      
      // Run the initialization function if it exists
      try {
        final initFn = _module!.lookupFunction('_initialize');
        initFn();
      } catch (e) {
        // Initialization function is optional
        print('No initialization function found: $e');
      }
      
      notifyListeners();
    } catch (e, stack) {
      print('Error loading WASM: $e');
      print(stack);
      rethrow;
    }
  }
  
  /// Set up bindings between WASM memory and Dart state
  void _setupStateBindings() {
    if (_module == null || _memory == null) return;
    
    try {
      // Register state update callback
      _module!.registerFunction('update_state', (String key, dynamic value) {
        _state[key] = value;
        notifyListeners();
      });
      
      // Register state read callback
      _module!.registerFunction('read_state', (String key) {
        return _state[key] ?? 0;
      });
      
      // Set up memory observer
      // This would watch for changes in specific memory regions
      // and update the state accordingly
      _setupMemoryObserver();
    } catch (e) {
      print('Error setting up state bindings: $e');
    }
  }
  
  /// Set up an observer for WASM memory changes
  void _setupMemoryObserver() {
    // In a real implementation, this would set up a periodic check
    // of specific memory regions that correspond to state variables
    
    // For now, we'll simulate this with a simple timer
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_memory != null) {
        // Read the first 4 bytes as a counter value
        final countValue = _memory!.asByteData().getUint32(0, Endian.little);
        if (_state['count'] != countValue) {
          _state['count'] = countValue;
          notifyListeners();
        }
        
        // Continue observing if the runtime is still active
        if (_runtime != null) {
          _setupMemoryObserver();
        }
      }
    });
  }
  
  /// Call a function in the WASM module
  dynamic callFunction(String name, List<dynamic> args) {
    if (_module == null) return null;
    
    try {
      final fn = _module!.lookupFunction(name);
      return fn(args);
    } catch (e) {
      print('Error calling function $name: $e');
      return null;
    }
  }
  
  /// Update a state variable
  void updateState(String key, dynamic value) {
    _state[key] = value;
    
    // If we have a WASM module, update the corresponding memory
    if (_module != null && _memory != null) {
      try {
        // Call the WASM function to update state
        callFunction('set_state', [key, value]);
      } catch (e) {
        print('Error updating WASM state: $e');
      }
    }
    
    notifyListeners();
  }
  
  /// Dispose the runtime
  @override
  void dispose() {
    _runtime?.dispose();
    _runtime = null;
    _module = null;
    _memory = null;
    super.dispose();
  }
}