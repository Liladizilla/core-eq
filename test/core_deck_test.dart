import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/screens/core_deck.dart';

void main() {
  testWidgets('command deck clearly identifies prototype state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CoreDeckScreen()));

    expect(find.text('CORE-EQ'), findsOneWidget);
    expect(find.text('SIGNAL PATH'), findsOneWidget);
    expect(find.text('UI PREVIEW'), findsWidgets);
    expect(find.text('NOT MEASURED'), findsOneWidget);
  });

  testWidgets('master bypass changes visible state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CoreDeckScreen()));

    await tester.tap(find.text('BYPASS').last);
    await tester.pumpAndSettle();

    expect(find.text('BYPASSED'), findsWidgets);
  });

  testWidgets('preset picker applies a named preset', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CoreDeckScreen()));

    await tester.tap(find.text('NEUTRAL REFERENCE').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAR CABIN').last);
    await tester.pumpAndSettle();

    expect(find.text('CAR CABIN'), findsOneWidget);
  });
}
