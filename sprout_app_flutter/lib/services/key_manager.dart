// flutter/lib/services/key_manager.dart
import 'package:local_auth/local_auth.dart';
import 'e2ee.dart';

class KeyManager {
  static final KeyManager _instance = KeyManager._internal();
  factory KeyManager() => _instance;
  KeyManager._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _biometricsEnabled = false;
  AsymmetricKeyPair<ECPublicKey, ECPrivateKey>? _cachedKeys;

  Future<bool> canUseBiometrics() async {
    return await _auth.canCheckBiometrics();
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Confirm it’s you to access your apps',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on Exception {
      return false;
    }
  }

  Future<AsymmetricKeyPair<ECPublicKey, ECPrivateKey>> getKeys() async {
    if (_cachedKeys != null) return _cachedKeys!;

    if (_biometricsEnabled) {
      final authenticated = await authenticate();
      if (!authenticated) throw Exception("Authentication failed");
    }

    // In real app: load from secure storage
    final keys = E2EE().generateKeyPair();
    _cachedKeys = keys;
    return keys;
  }

  Future<void> enableBiometrics() async {
    final authenticated = await authenticate();
    if (authenticated) {
      _biometricsEnabled = true;
    }
  }

  void disableBiometrics() {
    _biometricsEnabled = false;
  }
}