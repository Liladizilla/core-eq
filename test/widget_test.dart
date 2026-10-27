import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/main.dart';

void main() {
  testWidgets('CORE-EQ boots into the Command Deck', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.text('CORE-EQ'), findsOneWidget);
    expect(find.text('SIGNAL PATH'), findsOneWidget);
  });
}
