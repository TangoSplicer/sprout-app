import 'native_bridge.dart';

/// Adds a named Sprout app proxy to an Android home screen.
///
/// A proxy is deliberately not a separately signed APK. It opens the chosen
/// project directly inside Sprout’s validated runtime, so every project remains
/// editable, sandboxed, and updated by the host app while still feeling like a
/// dedicated app icon to the user.
class InstallService {
  static Future<bool> canInstall() async => true;

  static Future<void> installApp(String projectName) async {
    final safeName = projectName.trim();
    if (safeName.length < 2 || safeName.length > 80) {
      throw const InstallException(
          'Choose a valid app name before adding it to the home screen.');
    }
    final requested = await NativeBridge.requestAppShortcut(safeName);
    if (!requested) {
      throw const InstallException(
        'This Android launcher does not support adding Sprout apps to the home screen.',
      );
    }
  }
}

class InstallException implements Exception {
  final String message;

  const InstallException(this.message);

  @override
  String toString() => message;
}
