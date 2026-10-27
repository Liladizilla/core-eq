import 'package:flutter/material.dart';
import 'screens/core_deck.dart';

void main() {
  runApp(const CoreEqApp());
}

class CoreEqApp extends StatelessWidget {
  const CoreEqApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'CORE-EQ',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF07090C),
        colorScheme: base.colorScheme.copyWith(
          primary: const Color(0xFF00E5FF),
          secondary: const Color(0xFFFFB300),
        ),
      ),
      home: const CoreDeckScreen(),
    );
  }
}
