// flutter/lib/screens/preview_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/reactive_runtime.dart';
import '../services/project_service.dart';
import '../widgets/preview_container.dart';

class PreviewScreen extends StatefulWidget {
  final String code;

  const PreviewScreen({super.key, required this.code});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final ReactiveRuntime runtime = ReactiveRuntime();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wasm = await ProjectService().compileCode(widget.code);
    if (wasm.isNotEmpty) {
      // For now, just set initial state since load() is not implemented
      runtime.setValue('count', 0);
    }
  }

  @override
  void dispose() {
    runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: Center(
        child: PreviewContainer(
          child: ChangeNotifierProvider.value(
            value: runtime,
            child: Consumer<ReactiveRuntime>(
              builder: (ctx, rt, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Tap to grow', style: TextStyle(fontSize: 20)),
                    const SizedBox(height: 16),
                    Text('${rt.getValue('count', 0)}', style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // In real system: WASM handles this
                        // For now: simulate
                        rt.setValue('count', rt.getValue('count', 0) + 1);
                      },
                      child: const Text('++'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}