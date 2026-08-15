import 'package:flutter/material.dart';

import '../services/native_bridge.dart';
import '../services/sprout_app_package.dart';
import '../theme/sprout_theme.dart';

class ShareScreen extends StatefulWidget {
  final String projectName;

  const ShareScreen({super.key, required this.projectName});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final SproutAppPackageService _packages = SproutAppPackageService();
  bool _includeAppState = false;
  bool _sharing = false;
  String? _error;
  SproutPackageManifest? _lastManifest;

  Future<void> _share() async {
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      final export = await _packages.exportProject(
        widget.projectName,
        includeAppState: _includeAppState,
      );
      await NativeBridge.shareAppPackage(export.file.path);
      if (!mounted) return;
      setState(() => _lastManifest = export.manifest);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Share this app')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: SproutTheme.peach,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.send_to_mobile_outlined,
                          color: SproutTheme.forest, size: 30),
                      const SizedBox(height: 14),
                      Text(
                        widget.projectName,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Send a complete, editable Sprout app. The recipient can add it to their own Sprout garden, change the source, and keep using it independently.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('What travels',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                const _PackageFeature(
                  icon: Icons.account_tree_outlined,
                  title: 'The complete app design',
                  detail:
                      'Screens, flows, forms, calculations, and language source are all included.',
                ),
                const _PackageFeature(
                  icon: Icons.edit_note_outlined,
                  title: 'A recipient-owned copy',
                  detail:
                      'The other person receives a separate editable app. Your app is never overwritten.',
                ),
                const SizedBox(height: 14),
                Card(
                  child: SwitchListTile.adaptive(
                    value: _includeAppState,
                    onChanged: _sharing
                        ? null
                        : (value) => setState(() => _includeAppState = value),
                    secondary: Icon(
                      _includeAppState
                          ? Icons.data_object_outlined
                          : Icons.lock_outline,
                    ),
                    title: const Text('Include my saved app data'),
                    subtitle: Text(
                      _includeAppState
                          ? 'The recipient will receive current entries, notes, and local records saved in this app.'
                          : 'Only the reusable app design is shared. The recipient starts with their own empty data.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _PrivacyNotice(includeAppState: _includeAppState),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Card(
                    color: scheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline,
                              color: scheme.onErrorContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_error!,
                                style:
                                    TextStyle(color: scheme.onErrorContainer)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_lastManifest != null) ...[
                  const SizedBox(height: 14),
                  Card(
                    color: scheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.verified_outlined,
                              color: scheme.onSecondaryContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Package prepared and integrity-checked. Choose a person or app from Android’s sharing panel.',
                              style:
                                  TextStyle(color: scheme.onSecondaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _sharing ? null : _share,
                  icon: _sharing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_outlined),
                  label: Text(
                      _sharing ? 'Preparing your app…' : 'Share app package'),
                ),
                const SizedBox(height: 10),
                Text(
                  'The shared .sproutapp package is versioned, bounded in size, and checked again by the recipient before it is imported.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _PackageFeature({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: SproutTheme.sage,
            foregroundColor: SproutTheme.forest,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  final bool includeAppState;

  const _PrivacyNotice({required this.includeAppState});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.privacy_tip_outlined, color: scheme.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                includeAppState
                    ? 'Check saved entries carefully. Personal notes, records, and other local app data will travel with this package.'
                    : 'Private entries stay on this device. The recipient receives the reusable app structure, not your saved content.',
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
