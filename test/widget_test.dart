import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/main.dart';

void main() {
  testWidgets('CORE-EQ boots into the hardware-inspired visualizer', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.text('CORE-EQ'), findsOneWidget);
    expect(find.text('SPATIAL RESPONSE'), findsOneWidget);
    expect(find.text('PROCESSING CHAIN'), findsOneWidget);
    expect(find.text('VISUAL DEMO'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('spectrum mode switches the visualizer label', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    await tester.tap(find.text('SPECTRUM'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('SPECTRUM / FFT'), findsOneWidget);
  });

  testWidgets('master bypass exposes bypass state', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    await tester.tap(find.text('MASTER BYPASS'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('PROCESSING BYPASSED'), findsOneWidget);
    expect(find.text('BYPASS'), findsOneWidget);
  });
}
