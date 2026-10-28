import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/engine/core_eq_android_audio.dart';

void main() {
  group('CoreEqAndroidAudioStatus.fromMap', () {
    test('decodes running playback metadata', () {
      final status = CoreEqAndroidAudioStatus.fromMap({
        'running': true,
        'sampleRateHz': 48000,
        'channels': 2,
        'source': 'generated_test_tone',
        'frequencyHz': 125,
        'amplitude': 0.06,
        'peakLevel': 0.12,
        'error': null,
      });

      expect(status.running, isTrue);
      expect(status.sampleRateHz, 48000);
      expect(status.channels, 2);
      expect(status.source, 'generated_test_tone');
      expect(status.frequencyHz, 125);
      expect(status.amplitude, 0.06);
      expect(status.peakLevel, closeTo(0.12, 0.0001));
      expect(status.error, isNull);
    });

    test('defaults missing frequency to 440 Hz for older native plugins', () {
      final status = CoreEqAndroidAudioStatus.fromMap({'running': false});
      expect(status.frequencyHz, 440);
      expect(status.amplitude, 0.06);
    });

    test('uses safe defaults for malformed platform values', () {
      final status = CoreEqAndroidAudioStatus.fromMap({
        'running': 'yes',
        'sampleRateHz': '48000',
        'channels': false,
        'source': 123,
        'peakLevel': 'loud',
      });

      expect(status.running, isFalse);
      expect(status.sampleRateHz, 0);
      expect(status.channels, 0);
      expect(status.source, 'unknown');
      expect(status.peakLevel, 0.0);
      expect(status.error, isNull);
    });

    test('clamps native peak values into the supported range', () {
      final above = CoreEqAndroidAudioStatus.fromMap({'peakLevel': 2.5});
      final below = CoreEqAndroidAudioStatus.fromMap({'peakLevel': -0.5});
      final nan = CoreEqAndroidAudioStatus.fromMap({'peakLevel': double.nan});
      expect(above.peakLevel, 1.0);
      expect(below.peakLevel, 0.0);
      expect(nan.peakLevel, 0.0);
    });

    test('preserves a platform-reported error', () {
      final status = CoreEqAndroidAudioStatus.fromMap({
        'running': false,
        'sampleRateHz': 48000,
        'channels': 2,
        'source': 'generated_test_tone',
        'peakLevel': 0.0,
        'error': 'AudioTrack initialization failed.',
      });

      expect(status.running, isFalse);
      expect(status.error, 'AudioTrack initialization failed.');
    });
  });
  test('forwards spatial enablement to the Android audio channel', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('core_eq_audio_test');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    final audio = CoreEqAndroidAudio(channel: channel);
    await audio.setSpatialEnabled(true);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'setSpatialEnabled');
    expect(calls.single.arguments, {'enabled': true});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });


test('forwards selected frequency to the Android audio channel', () async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('core_eq_audio_frequency_test');
  final calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    calls.add(call);
    return {
      'running': true,
      'sampleRateHz': 48000,
      'channels': 2,
      'source': 'generated_test_tone',
      'frequencyHz': 64,
      'amplitude': 0.04,
      'peakLevel': 0.1,
    };
  });

  final audio = CoreEqAndroidAudio(channel: channel);
  final status = await audio.startTestTone(frequencyHz: 64, amplitude: 0.04);
  expect(calls.single.method, 'startTestTone');
  expect(calls.single.arguments, {'frequencyHz': 64, 'amplitude': 0.04});
  expect(status.frequencyHz, 64);
  expect(status.amplitude, 0.04);

  await expectLater(audio.startTestTone(frequencyHz: 55), throwsArgumentError);
  await expectLater(audio.startTestTone(amplitude: 0.5), throwsArgumentError);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
});

}
