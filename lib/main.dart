import 'package:flutter/material.dart';
import 'screens/core_visualizer.dart';

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
        scaffoldBackgroundColor: const Color(0xFF080A0D),
        colorScheme: base.colorScheme.copyWith(
          primary: const Color(0xFF62E6E3),
          secondary: const Color(0xFFFFB45C),
        ),
      ),
      home: const CoreVisualizerScreen(),
    );
  }
}
