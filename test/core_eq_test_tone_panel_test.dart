import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/engine/core_eq_android_audio.dart';
import 'package:core_eq/widgets/core_eq_test_tone_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('core_eq_panel_widget_test');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows bounded level and frequency choices', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CoreEqTestTonePanel(
          audio: CoreEqAndroidAudio(channel: channel),
          androidPlatformOverride: true,
        ),
      ),
    ));

    expect(find.text('ANDROID AUDIO TEST'), findsOneWidget);
    expect(find.text('TEST FREQUENCY'), findsOneWidget);
    expect(find.text('440 Hz'), findsOneWidget);
    expect(find.text('6% amplitude'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('START TEST TONE'), findsOneWidget);
    expect(find.textContaining('does not capture microphone'), findsOneWidget);
  });

  testWidgets('forwards selected frequency and level when starting', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'startTestTone') {
        final arguments = call.arguments as Map<Object?, Object?>;
        return <Object?, Object?>{
          'running': true,
          'sampleRateHz': 48000,
          'channels': 2,
          'source': 'generated_test_tone',
          'frequencyHz': arguments['frequencyHz'],
          'amplitude': arguments['amplitude'],
          'peakLevel': 0.06,
        };
      }
      return <Object?, Object?>{'running': false};
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CoreEqTestTonePanel(
          audio: CoreEqAndroidAudio(channel: channel),
          androidPlatformOverride: true,
        ),
      ),
    ));

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('125 Hz').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('START TEST TONE'));
    await tester.tap(find.text('START TEST TONE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    final start = calls.firstWhere((call) => call.method == 'startTestTone');
    final arguments = start.arguments as Map<Object?, Object?>;
    expect(arguments['frequencyHz'], 125);
    expect(arguments['amplitude'], closeTo(0.06, 0.0001));
    expect(find.text('STOP TEST TONE'), findsOneWidget);
    expect(find.textContaining('Generated 125 Hz tone is playing'), findsOneWidget);
  });

  testWidgets('disables playback outside Android', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CoreEqTestTonePanel(
          audio: CoreEqAndroidAudio(channel: channel),
          androidPlatformOverride: false,
        ),
      ),
    ));

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
    expect(find.text('Android only. No audio is started on this platform.'), findsOneWidget);
  });
}
