/// FFI bridge for the Sprout compiler native library.
library;

import 'dart:developer' as developer;
import 'dart:ffi';

import 'package:ffi/ffi.dart';

class SproutCompiler {
  final DynamicLibrary _library;

  SproutCompiler(this._library);

  String compileSproutScript(String sourceCode) {
    final source = sourceCode.toNativeUtf8();
    try {
      return _readOwnedString(_compileSproutScript(source));
    } finally {
      calloc.free(source);
    }
  }

  String parseSproutScript(String sourceCode) {
    final source = sourceCode.toNativeUtf8();
    try {
      return _readOwnedString(_parseSproutScript(source));
    } finally {
      calloc.free(source);
    }
  }

  bool validateCode(String sourceCode) {
    final source = sourceCode.toNativeUtf8();
    try {
      return _validateCode(source) != 0;
    } finally {
      calloc.free(source);
    }
  }

  String getLastError() => _readOwnedString(_getLastError());

  String getVersion() => _readOwnedString(_getVersion());

  late final Pointer<Utf8> Function(Pointer<Utf8>) _compileSproutScript =
      _library
          .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>(
            'compile_sprout_script',
          )
          .asFunction();

  late final Pointer<Utf8> Function(Pointer<Utf8>) _parseSproutScript = _library
      .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>(
        'parse_sprout_script',
      )
      .asFunction();

  late final int Function(Pointer<Utf8>) _validateCode = _library
      .lookup<NativeFunction<Int8 Function(Pointer<Utf8>)>>('validate_code')
      .asFunction();

  late final Pointer<Utf8> Function() _getLastError = _library
      .lookup<NativeFunction<Pointer<Utf8> Function()>>('get_last_error')
      .asFunction();

  late final Pointer<Utf8> Function() _getVersion = _library
      .lookup<NativeFunction<Pointer<Utf8> Function()>>('get_version')
      .asFunction();

  late final void Function(Pointer<Utf8>) _freeString = _library
      .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>(
          'sprout_string_free')
      .asFunction();

  String _readOwnedString(Pointer<Utf8> pointer) {
    if (pointer.address == 0) {
      throw StateError('Sprout compiler returned a null string pointer');
    }
    try {
      return pointer.toDartString();
    } finally {
      _freeString(pointer);
    }
  }
}

SproutCompiler? _compilerInstance;

SproutCompiler getCompiler() {
  _compilerInstance ??= SproutCompiler(
    DynamicLibrary.open('libsprout_compiler.so'),
  );
  return _compilerInstance!;
}

void initializeCompiler() {
  final version = getCompiler().getVersion();
  developer.log('Sprout Compiler initialized: $version',
      name: 'sprout.compiler');
}

void disposeCompiler() {
  _compilerInstance = null;
}
