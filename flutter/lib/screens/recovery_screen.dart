// flutter/lib/screens/recovery_screen.dart
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _recoveryPhrase = "sprout garden leaf water code grow plant idea simple trust secure future";
  List<bool> _confirmed = List.filled(12, false);
  final LocalAuthentication _auth = LocalAuthentication();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final canCheck = await _auth.canCheckBiometrics();
    setState(() {
      _canCheckBiometrics = canCheck;
    });
  }

  void _toggleWord(int index) {
    setState(() {
      _confirmed[index] = !_confirmed[index];
    });
  }

  bool get allConfirmed => _confirmed.every((b) => b);

  @override
  Widget build(BuildContext context) {
    final words = _recoveryPhrase.split(' ');

    return Scaffold(
      appBar: AppBar(title: const Text('Backup Your Keys')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔐 Save Your Recovery Phrase',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This is the only way to recover your apps if you lose your phone.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < words.length; i++)
                  ChoiceChip(
                    label: Text('${i + 1}. ${words[i]}'),
                    selected: _confirmed[i],
                    onSelected: (_) => _toggleWord(i),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (allConfirmed)
              const Text(
                '✅ Great! You’ve confirmed your recovery phrase.',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              )
            else
              const Text(
                'Tap each word after you’ve written it down.',
                style: TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 32),
            if (_canCheckBiometrics)
              ElevatedButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Enable Biometric Unlock'),
                onPressed: () async {
                  final didAuthenticate = await _auth.authenticate(
                    localizedReason: 'Use Face ID or fingerprint to unlock your apps',
                  );
                  if (didAuthenticate) {
                    // Store flag: biometrics enabled
                    Navigator.pop(context);
                  }
                },
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: allConfirmed ? () => Navigator.pop(context) : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}