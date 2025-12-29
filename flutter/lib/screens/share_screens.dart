// flutter/lib/screens/share_screen.dart
import 'package:flutter/material.dart';
import '../services/qr_service.dart';

class ShareScreen extends StatefulWidget {
  final String projectName;

  const ShareScreen({super.key, required this.projectName});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  Uint8List? _qrData;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final data = await QrService.generateQrData(widget.projectName);
    setState(() => _qrData = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share App')),
      body: _qrData == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Scan to share your app', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  QrService.buildQrWidget(_qrData!),
                  const SizedBox(height: 16),
                  const Text('Anyone can install this app', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
    );
  }
}