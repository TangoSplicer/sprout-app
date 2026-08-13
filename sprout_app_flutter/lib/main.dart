// flutter/lib/main.dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/sprout_theme.dart';

void main() {
  runApp(const SproutApp());
}

class SproutApp extends StatelessWidget {
  const SproutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sprout',
      debugShowCheckedModeBanner: false,
      theme: SproutTheme.light(),
      home: const HomeScreen(),
    );
  }
}
