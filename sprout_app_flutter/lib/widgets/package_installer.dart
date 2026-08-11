// flutter/lib/widgets/package_installer.dart
import 'package:flutter/material.dart';
import '../services/package_manager.dart';

class PackageInstaller extends StatefulWidget {
  const PackageInstaller({super.key});

  @override
  State<PackageInstaller> createState() => _PackageInstallerState();
}

class _PackageInstallerState extends State<PackageInstaller> {
  final TextEditingController _controller = TextEditingController();
  bool _installing = false;
  String _result = '';

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _result = '';
    });

    try {
      await PackageManager().installPackage(_controller.text);
      setState(() {
        _result = '✅ Installed ${_controller.text}';
      });
    } catch (e) {
      setState(() {
        _result = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _installing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Package',
            hintText: 'e.g., @sprout/ui or user/repo',
          ),
          onSubmitted: (_) => _install(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _installing ? null : _install,
            child: Text(_installing ? 'Installing...' : 'Install'),
          ),
        ),
        const SizedBox(height: 12),
        if (_result.isNotEmpty) Text(_result),
      ],
    );
  }
}