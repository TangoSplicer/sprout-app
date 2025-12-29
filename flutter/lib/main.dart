// flutter/lib/main.dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

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
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4A9D5E),
          secondary: Color(0xFFFFC107),
          background: Color(0xFFF8F9FA),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}