import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/main.dart';

void main() {
  testWidgets('CORE-EQ boots into the hardware-inspired visualizer', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.text('CORE-EQ'), findsOneWidget);
    expect(find.text('SPATIAL RESPONSE'), findsOneWidget);
    expect(find.text('PROCESSING CHAIN'), findsOneWidget);
    expect(find.text('VISUAL DEMO'), findsOneWidget);
    expect(find.text('ENGINE'), findsOneWidget);
    expect(find.text('NOT CONNECTED'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('spectrum mode switches the visualizer label and can switch back', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    await tester.ensureVisible(find.text('SPECTRUM'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('SPECTRUM'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('SPECTRUM / FFT'), findsOneWidget);

    await tester.tap(find.text('ORBITAL FIELD'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('FIELD / 360°'), findsOneWidget);
  });

  testWidgets('master bypass can be enabled and disabled', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    await tester.tap(find.text('MASTER BYPASS'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('PROCESSING BYPASSED'), findsOneWidget);
    expect(find.text('BYPASS'), findsOneWidget);

    await tester.tap(find.text('PROCESSING BYPASSED'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('MASTER BYPASS'), findsOneWidget);
    expect(find.text('VISUAL DEMO'), findsOneWidget);
  });

  testWidgets('selecting a module updates the stage detail panel', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    await tester.ensureVisible(find.text('DYNAMIC EQ'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('DYNAMIC EQ'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('STAGE 03 / FREQUENCY-DEPENDENT'), findsOneWidget);
  });

  testWidgets('reset restores the default intensity value', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    await tester.ensureVisible(find.text('RESET'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('64%'), findsOneWidget);
    await tester.tap(find.text('RESET'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('64%'), findsOneWidget);
  });

  testWidgets('demo telemetry explicitly reports unavailable live engine data', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.text('NOT CONNECTED'), findsOneWidget);
    expect(find.text('NOT MEASURED'), findsOneWidget);
    expect(find.text('ANIMATION: DEMO SIGNAL'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
  });
}
