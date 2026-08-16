// flutter/lib/services/native_bridge.dart
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('sprout/native');
  static Future<void> Function(String packagePath)? _incomingPackageHandler;
  static Future<void> Function(String projectName)? _proxyLaunchHandler;

  /// Registers the currently visible app-shell handlers for external Android
  /// intents. The home screen owns the handlers and clears them when disposed.
  static void setPlatformLaunchHandlers({
    Future<void> Function(String packagePath)? onIncomingPackage,
    Future<void> Function(String projectName)? onProxyLaunch,
  }) {
    _incomingPackageHandler = onIncomingPackage;
    _proxyLaunchHandler = onProxyLaunch;
    _channel.setMethodCallHandler((call) async {
      final value = call.arguments;
      if (call.method == 'incomingAppPackage' && value is String) {
        await _incomingPackageHandler?.call(value);
      } else if (call.method == 'proxyLaunchRequested' && value is String) {
        await _proxyLaunchHandler?.call(value);
      }
    });
  }

  static Future<String?> takePhoto() async {
    final result = await _channel.invokeMethod<String?>('takePhoto');
    return result ?? 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  static Future<String?> scanQrCode() async {
    return await _channel.invokeMethod('scanQrCode');
  }

  static Future<Map<String, double>> getCurrentLocation() async {
    final result = await _channel.invokeMethod('getCurrentLocation');
    return Map<String, double>.from(result);
  }

  static Future<void> vibrate(int ms) async {
    await _channel.invokeMethod('vibrate', {'duration': ms});
  }

  static Future<void> scheduleAlarm(String message, int timestamp) async {
    await _channel.invokeMethod('scheduleAlarm', {
      'message': message,
      'timestamp': timestamp,
    });
  }

  static Future<void> notifyUser(String message) async {
    try {
      await _channel.invokeMethod('notifyUser', {'message': message});
    } catch (_) {
      // Fallback if platform notification channel is unavailable
    }
  }

  static Future<void> playSound(String asset) async {
    await _channel.invokeMethod('playSound', {'asset': asset});
  }

  /// Opens Android's share sheet for a validated local `.sproutapp` file.
  static Future<void> shareAppPackage(String packagePath) async {
    await _channel.invokeMethod('shareAppPackage', {'path': packagePath});
  }

  /// Returns a copied local package path received through Android sharing, once.
  /// Incoming content is copied by the activity into private cache storage before
  /// Dart inspects the bounded archive.
  static Future<String?> consumeIncomingAppPackage() async {
    return _channel.invokeMethod<String>('consumeIncomingAppPackage');
  }

  /// Returns the project requested by a home-screen proxy shortcut, once.
  static Future<String?> consumeLaunchProject() async {
    return _channel.invokeMethod<String>('consumeLaunchProject');
  }

  /// Pins a named Sprout proxy shortcut to the Android home screen when the
  /// launcher supports it. The shortcut still executes inside Sprout.
  static Future<bool> requestAppShortcut(String projectName) async {
    return (await _channel.invokeMethod<bool>(
          'requestAppShortcut',
          {'projectName': projectName},
        )) ??
        false;
  }
}
