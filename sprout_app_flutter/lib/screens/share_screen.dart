import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/qr_service.dart';
import '../theme/sprout_theme.dart';

class ShareScreen extends StatefulWidget {
  final String projectName;

  const ShareScreen({super.key, required this.projectName});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  Uint8List? _qrData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() => _error = null);
    try {
      final data = await QrService.generateQrData(widget.projectName);
      if (!mounted) return;
      setState(() => _qrData = data);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _error = 'This project could not be prepared for sharing.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _qrData;
    return Scaffold(
      appBar: AppBar(title: const Text('Share project')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child:
                  data == null ? _buildLoadingOrError() : _buildShareCard(data),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOrError() {
    if (_error == null) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 18),
          Text('Preparing a project code…'),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: SproutTheme.clay),
        const SizedBox(height: 14),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    );
  }

  Widget _buildShareCard(Uint8List data) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: SproutTheme.peach,
              foregroundColor: scheme.primary,
              child: const Icon(Icons.qr_code_2_outlined, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              widget.projectName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan this code on another Sprout device to transfer this project’s source and project details.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: QrService.buildQrWidget(data),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined,
                      color: scheme.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Review the source before sharing. The recipient should also preview the project before relying on it.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
