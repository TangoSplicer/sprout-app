// flutter/lib/services/native_bridge.dart
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('sprout/native');

  static Future<void> takePhoto() async {
    await _channel.invokeMethod('takePhoto');
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

  static Future<void> playSound(String asset) async {
    await _channel.invokeMethod('playSound', {'asset': asset});
  }
}