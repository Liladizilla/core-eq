import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/main.dart';

void main() {
  testWidgets('CORE-EQ presents Android output effects as the primary controls', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.text('CORE-EQ'), findsOneWidget);
    expect(find.text('ANDROID OUTPUT EFFECTS'), findsOneWidget);
    expect(find.text('GLOBAL EQUALIZER'), findsOneWidget);
    expect(find.text('GLOBAL BASS BOOST'), findsOneWidget);
    expect(find.text('10-BAND OUTPUT EQ'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('global output panel explains unsupported devices honestly', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.textContaining('Checking whether this Android device exposes global output effects'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('This device has not exposed a usable global output'), findsOneWidget);
  });

  testWidgets('app-owned DSP is explicitly separated from external audio', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.text('LOCAL DSP LAB'), findsOneWidget);
    expect(find.text('LOCAL DSP PROFILE'), findsOneWidget);
    expect(find.text('LOCAL BASS BOOST'), findsOneWidget);
    expect(find.text('LOCAL GRAPHIC EQ'), findsOneWidget);
    expect(find.textContaining('It does not change Spotify or other apps'), findsOneWidget);
  });

  testWidgets('generated test tone remains diagnostic and is not presented as system audio', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.text('APP-OWNED DSP DIAGNOSTICS'), findsOneWidget);
    expect(find.textContaining('No audio stream connected'), findsOneWidget);
    expect(find.textContaining('They do not alter Spotify or other apps'), findsOneWidget);
  });

  testWidgets('visualizer clearly discloses that live audio is not connected', (tester) async {
    await tester.pumpWidget(const CoreEqApp());
    expect(find.textContaining('No audio stream connected'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pump(const Duration(milliseconds: 50));
  });
}
