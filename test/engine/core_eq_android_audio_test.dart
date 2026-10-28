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
        'error': null,
      });

      expect(status.running, isTrue);
      expect(status.sampleRateHz, 48000);
      expect(status.channels, 2);
      expect(status.source, 'generated_test_tone');
      expect(status.error, isNull);
    });

    test('uses safe defaults for malformed platform values', () {
      final status = CoreEqAndroidAudioStatus.fromMap({
        'running': 'yes',
        'sampleRateHz': '48000',
        'channels': false,
        'source': 123,
      });

      expect(status.running, isFalse);
      expect(status.sampleRateHz, 0);
      expect(status.channels, 0);
      expect(status.source, 'unknown');
      expect(status.error, isNull);
    });

    test('preserves a platform-reported error', () {
      final status = CoreEqAndroidAudioStatus.fromMap({
        'running': false,
        'sampleRateHz': 48000,
        'channels': 2,
        'source': 'generated_test_tone',
        'error': 'AudioTrack initialization failed.',
      });

      expect(status.running, isFalse);
      expect(status.error, 'AudioTrack initialization failed.');
    });
  });
}
