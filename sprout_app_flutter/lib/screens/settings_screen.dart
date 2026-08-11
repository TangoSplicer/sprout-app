// flutter/lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Theme'),
            subtitle: Text('Light'),
          ),
          const ListTile(
            title: Text('Auto-save'),
            trailing: Switch(value: true, onChanged: null),
          ),
          const ListTile(
            title: Text('On-device AI'),
            subtitle: Text('TinyLlama • 100MB'),
            trailing: Switch(value: true, onChanged: null),
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Sprout',
                children: [
                  const Text('All data stays on your device.'),
                  const Text('No code leaves your phone.'),
                ],
              );
            },
          ),
          const ListTile(
            title: Text('Version'),
            subtitle: Text('v0.1.0-alpha'),
          ),
        ],
      ),
    );
  }
}