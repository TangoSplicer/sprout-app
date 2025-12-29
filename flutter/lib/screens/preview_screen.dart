// flutter/lib/screens/preview_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/reactive_runtime.dart';
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
      await runtime.load(wasm, initialState: {'count': 0});
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
                    Text('${rt.state['count']}', style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // In real system: WASM handles this
                        // For now: simulate
                        if (rt.memory != null) {
                          rt.memory!.buffer.asByteData().setUint32(0, (rt.state['count'] ?? 0) + 1, Endian.little);
                        }
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