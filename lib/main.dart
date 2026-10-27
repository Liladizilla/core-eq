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
    const accent = Color(0xFF7CE7DF);
    const background = Color(0xFF090B0E);
    const surface = Color(0xFF12161B);
    const outline = Color(0xFF293139);
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: outline),
    );

    return MaterialApp(
      title: 'CORE-EQ',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: background,
        colorScheme: base.colorScheme.copyWith(
          primary: accent,
          secondary: const Color(0xFFFFBD72),
          surface: surface,
          outline: outline,
        ),
        cardTheme: CardTheme(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: outline)),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(shape: rounded, elevation: 0),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(shape: rounded),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(shape: rounded),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? accent : const Color(0xFF89949D)),
          trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? accent.withValues(alpha: .28) : outline),
        ),
        sliderTheme: base.sliderTheme.copyWith(
          activeTrackColor: accent,
          inactiveTrackColor: outline,
          thumbColor: const Color(0xFFF1F3F4),
          trackHeight: 3,
        ),
      ),
      home: const CoreVisualizerScreen(),
    );
  }
}
