// Biometric Authentication Service for Sprout
// Provides secure biometric authentication

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart' as local_auth;
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

enum BiometricType { none, fingerprint, face, iris }

enum BiometricResult { success, failed, canceled, error, notAvailable }

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final local_auth.LocalAuthentication _auth = local_auth.LocalAuthentication();
  BiometricType _availableBiometric = BiometricType.none;

  // Security: Check biometric availability
  Future<BiometricType> checkAvailability() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();

      if (!isAvailable || !isDeviceSupported) {
        _availableBiometric = BiometricType.none;
        return BiometricType.none;
      }

      final availableBiometrics = await _auth.getAvailableBiometrics();

      if (availableBiometrics.contains(local_auth.BiometricType.face)) {
        _availableBiometric = BiometricType.face;
      } else if (availableBiometrics
          .contains(local_auth.BiometricType.fingerprint)) {
        _availableBiometric = BiometricType.fingerprint;
      } else if (availableBiometrics.contains(local_auth.BiometricType.iris)) {
        _availableBiometric = BiometricType.iris;
      } else {
        _availableBiometric = BiometricType.none;
      }

      return _availableBiometric;
    } catch (e) {
      _availableBiometric = BiometricType.none;
      return BiometricType.none;
    }
  }

  // Security: Authenticate user with biometrics
  Future<BiometricResult> authenticate({
    String localizedReason = 'Authenticate to access Sprout',
    bool useErrorDialogs = true,
    bool stickyAuth = false,
    bool biometricOnly = true,
  }) async {
    try {
      // Security: Check availability first
      if (_availableBiometric == BiometricType.none) {
        await checkAvailability();
      }

      if (_availableBiometric == BiometricType.none) {
        return BiometricResult.notAvailable;
      }

      // Security: Authenticate
      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        authMessages: [
          const AndroidAuthMessages(signInTitle: 'Sprout Authentication'),
          const IOSAuthMessages(cancelButton: 'Cancel'),
        ],
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: biometricOnly,
        ),
      );

      return didAuthenticate ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      // Security: Handle specific errors
      if (e.code == 'not_available') {
        return BiometricResult.notAvailable;
      } else if (e.code == 'not_enrolled') {
        return BiometricResult.notAvailable;
      } else if (e.code == 'locked_out' || e.code == 'permanently_locked_out') {
        return BiometricResult.error;
      } else if (e.code == 'user_canceled') {
        return BiometricResult.canceled;
      } else {
        return BiometricResult.error;
      }
    } catch (e) {
      return BiometricResult.error;
    }
  }

  // Security: Stop authentication
  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      // Ignore errors
    }
  }

  // Security: Check if biometrics are enrolled
  Future<bool> isBiometricEnrolled() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final availableBiometrics = await _auth.getAvailableBiometrics();
      return isAvailable && availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Security: Get available biometric types
  Future<List<BiometricType>> getAvailableTypes() async {
    try {
      final availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics
          .map((type) {
            if (type == local_auth.BiometricType.face) {
              return BiometricType.face;
            }
            if (type == local_auth.BiometricType.fingerprint) {
              return BiometricType.fingerprint;
            }
            if (type == local_auth.BiometricType.iris) {
              return BiometricType.iris;
            }
            return BiometricType.none;
          })
          .where((type) => type != BiometricType.none)
          .toList(growable: false);
    } catch (e) {
      return [];
    }
  }

  // Security: Get biometric type name
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.none:
        return 'None';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.iris:
        return 'Iris';
    }
  }

  // Security: Check if device supports biometrics
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  // Security: Get authentication status
  Future<Map<String, dynamic>> getAuthenticationStatus() async {
    final isAvailable = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    final availableBiometrics = await _auth.getAvailableBiometrics();

    return {
      'is_available': isAvailable,
      'is_supported': isSupported,
      'available_biometrics':
          availableBiometrics.map((e) => e.toString()).toList(),
      'current_biometric': _availableBiometric.toString(),
    };
  }
}
