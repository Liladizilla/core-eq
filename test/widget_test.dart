import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/main.dart';

void main() {
  testWidgets('CORE-EQ boots into the hardware-inspired visualizer', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.text('CORE-EQ'), findsOneWidget);
    expect(find.text('SPATIAL RESPONSE'), findsOneWidget);
    expect(find.text('PROCESSING CHAIN'), findsOneWidget);
    expect(find.text('VISUAL DEMO'), findsOneWidget);
  });
}
