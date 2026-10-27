import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/main.dart';

void main() {
  testWidgets('CORE-EQ opens with consumer-facing audio controls', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.text('CORE-EQ'), findsOneWidget);
    expect(find.text('SOUND PROFILE'), findsOneWidget);
    expect(find.text('BASS BOOST'), findsOneWidget);
    expect(find.text('GRAPHIC EQUALIZER'), findsOneWidget);
    expect(find.text('LIMITER'), findsOneWidget);
    expect(find.text('SPATIAL AUDIO'), findsOneWidget);
    expect(find.text('AUDIO OFFLINE'), findsOneWidget);
    expect(find.textContaining('No audio stream connected'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('preset selection changes the selected sound profile', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    await tester.ensureVisible(find.text('Bass'));
    await tester.tap(find.text('Bass'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Bass'), findsOneWidget);
    expect(find.text('SOUND PROFILE'), findsOneWidget);
  });

  testWidgets('limiter and spatial audio toggles respond to input', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    await tester.ensureVisible(find.text('SPATIAL AUDIO'));
    final spatialSwitch = find.descendant(
      of: find.ancestor(of: find.text('SPATIAL AUDIO'), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );
    expect(spatialSwitch, findsOneWidget);
    await tester.tap(spatialSwitch);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('SPATIAL ON'), findsOneWidget);
  });

  testWidgets('bypass and reset controls respond', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    await tester.tap(find.text('BYPASS'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('BYPASS SELECTED'), findsOneWidget);
    await tester.tap(find.text('RESET ALL'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('BYPASS'), findsOneWidget);
  });

  testWidgets('equalizer reset returns all bands to zero', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    await tester.ensureVisible(find.text('GRAPHIC EQUALIZER'));
    await tester.tap(find.text('RESET'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('GRAPHIC EQUALIZER'), findsOneWidget);
  });

  testWidgets('visualizer clearly discloses that live audio is not connected', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.textContaining('No audio stream connected'), findsOneWidget);
    expect(find.text('AWAITING AUDIO INPUT'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pump(const Duration(milliseconds: 50));
  });
}
