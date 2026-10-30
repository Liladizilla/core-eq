import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/engine/core_eq_android_audio.dart';

void main() {
  group('CoreEqMediaStatus diagnostics', () {
    test('parses active DSP format, frame count and peak levels', () {
      final status = CoreEqMediaStatus.fromMap(<Object?, Object?>{
        'isPlaying': true,
        'playWhenReady': true,
        'state': 'ready',
        'positionMs': 1250,
        'durationMs': 90000,
        'mediaUri': 'file:///music/test.flac',
        'inputPeakLevel': 0.42,
        'outputPeakLevel': 1.08,
        'processedFrames': 48000,
        'sampleRateHz': 48000,
        'channels': 2,
      });

      expect(status.isPlaying, isTrue);
      expect(status.state, 'ready');
      expect(status.inputPeakLevel, closeTo(0.42, 0.0001));
      expect(status.outputPeakLevel, closeTo(1.08, 0.0001));
      expect(status.processedFrames, 48000);
      expect(status.sampleRateHz, 48000);
      expect(status.channels, 2);
    });

    test('defaults missing diagnostics for older or idle native responses', () {
      final status = CoreEqMediaStatus.fromMap(<Object?, Object?>{
        'isPlaying': false,
        'playWhenReady': false,
        'state': 'idle',
      });

      expect(status.inputPeakLevel, 0);
      expect(status.outputPeakLevel, 0);
      expect(status.processedFrames, 0);
      expect(status.sampleRateHz, 0);
      expect(status.channels, 0);
      expect(status.mediaUri, isNull);
    });

    test('rejects invalid peak values without propagating NaN or negatives', () {
      final status = CoreEqMediaStatus.fromMap(<Object?, Object?>{
        'inputPeakLevel': double.nan,
        'outputPeakLevel': -0.5,
        'processedFrames': -10,
      });

      expect(status.inputPeakLevel, 0);
      expect(status.outputPeakLevel, 0);
      expect(status.processedFrames, 0);
    });
  });
}
