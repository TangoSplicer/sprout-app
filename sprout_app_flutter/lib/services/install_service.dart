/// Installation is intentionally unavailable inside the editor until a real,
/// signed Android packaging pipeline is integrated. The former implementation
/// wrote arbitrary text to a file ending in `.apk` and attempted to install it.
class InstallService {
  static Future<bool> canInstall() async => false;

  static Future<void> installApp(String projectName) async {
    throw UnsupportedError(
      'On-device APK packaging is unavailable. Export the project and build a signed release through the release pipeline.',
    );
  }
}
