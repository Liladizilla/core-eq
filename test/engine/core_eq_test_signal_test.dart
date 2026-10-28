import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/engine/core_eq_test_signal.dart';

void main() {
  group('CoreEqPcmProbe.generateSine', () {
    test('writes deterministic interleaved stereo samples', () {
      final pcm = calloc.allocate<Float>(8 * sizeOf<Float>());
      try {
        CoreEqPcmProbe.generateSine(
          pcm,
          frames: 4,
          channels: 2,
          sampleRateHz: 4,
          frequencyHz: 1,
          amplitude: 0.5,
        );

        expect(pcm[0], 0);
        expect(pcm[1], 0);
        expect(pcm[2], closeTo(0.5, 1e-6));
        expect(pcm[3], closeTo(0.5, 1e-6));
        expect(pcm[4], closeTo(0, 1e-6));
        expect(pcm[5], closeTo(0, 1e-6));
        expect(pcm[6], closeTo(-0.5, 1e-6));
        expect(pcm[7], closeTo(-0.5, 1e-6));
      } finally {
        calloc.free(pcm);
      }
    });

    test('rejects frequencies at or above Nyquist', () {
      final pcm = calloc.allocate<Float>(2 * sizeOf<Float>());
      try {
        expect(
          () => CoreEqPcmProbe.generateSine(
            pcm,
            frames: 2,
            channels: 1,
            sampleRateHz: 48000,
            frequencyHz: 24000,
            amplitude: 0.5,
          ),
          throwsArgumentError,
        );
      } finally {
        calloc.free(pcm);
      }
    });

    test('rejects invalid frame counts, channels, and amplitude', () {
      final pcm = calloc.allocate<Float>(2 * sizeOf<Float>());
      try {
        void generate({int frames = 2, int channels = 1, double amplitude = 0.5}) {
          CoreEqPcmProbe.generateSine(
            pcm,
            frames: frames,
            channels: channels,
            sampleRateHz: 48000,
            frequencyHz: 1000,
            amplitude: amplitude,
          );
        }

        expect(() => generate(frames: 0), throwsArgumentError);
        expect(() => generate(channels: 3), throwsArgumentError);
        expect(() => generate(amplitude: 0), throwsArgumentError);
        expect(() => generate(amplitude: 1.01), throwsArgumentError);
        expect(() => generate(amplitude: double.nan), throwsArgumentError);
      } finally {
        calloc.free(pcm);
      }
    });
  });
}
