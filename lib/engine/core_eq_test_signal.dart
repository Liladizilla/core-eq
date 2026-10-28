import 'dart:math' as math;
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../native/core_eq_native.dart';

/// Result of processing a generated PCM block through the native DSP.
final class CoreEqPcmProbeResult {
  const CoreEqPcmProbeResult({
    required this.processStatus,
    required this.peakStatus,
    required this.outputPeak,
    required this.frames,
    required this.channels,
    required this.sampleRateHz,
    required this.frequencyHz,
  });

  final CoreEqStatus processStatus;
  final CoreEqStatus peakStatus;
  /// Linear amplitude reported by the native meter, or null on meter failure.
  final double? outputPeak;
  final int frames;
  final int channels;
  final double sampleRateHz;
  final double frequencyHz;

  bool get succeeded =>
      processStatus == CoreEqStatus.ok &&
      peakStatus == CoreEqStatus.ok &&
      outputPeak != null;
}

/// Generates deterministic sine-wave PCM and runs it through CORE-EQ.
///
/// This is a native DSP diagnostic, not an audio output or capture stream.
/// Samples are held in temporary native memory and never sent through a
/// Flutter platform channel.
final class CoreEqPcmProbe {
  const CoreEqPcmProbe._();

  static CoreEqPcmProbeResult run(
    CoreEqEngineSession session, {
    int frames = 4800,
    int channels = 2,
    double sampleRateHz = 48000,
    double frequencyHz = 1000,
    double amplitude = 0.5,
  }) {
    if (frames <= 0 || (channels != 1 && channels != 2)) {
      throw ArgumentError('frames must be positive and channels must be 1 or 2.');
    }
    if (!sampleRateHz.isFinite ||
        !frequencyHz.isFinite ||
        !amplitude.isFinite ||
        sampleRateHz <= 0 ||
        frequencyHz <= 0 ||
        frequencyHz >= sampleRateHz / 2 ||
        amplitude <= 0 ||
        amplitude > 1) {
      throw ArgumentError('Invalid sample rate, frequency, or amplitude.');
    }

    final sampleCount = frames * channels;
    final pcm = calloc<Float>(sampleCount);
    try {
      generateSine(
        pcm,
        frames: frames,
        channels: channels,
        sampleRateHz: sampleRateHz,
        frequencyHz: frequencyHz,
        amplitude: amplitude,
      );
      final processStatus = session.process(
        samples: pcm,
        frames: frames,
        channels: channels,
      );
      if (processStatus != CoreEqStatus.ok) {
        return CoreEqPcmProbeResult(
          processStatus: processStatus,
          peakStatus: CoreEqStatus.unknown,
          outputPeak: null,
          frames: frames,
          channels: channels,
          sampleRateHz: sampleRateHz,
          frequencyHz: frequencyHz,
        );
      }
      final reading = session.readPeakLevel();
      return CoreEqPcmProbeResult(
        processStatus: processStatus,
        peakStatus: reading.status,
        outputPeak: reading.level,
        frames: frames,
        channels: channels,
        sampleRateHz: sampleRateHz,
        frequencyHz: frequencyHz,
      );
    } finally {
      calloc.free(pcm);
    }
  }

  /// Fills caller-owned native memory with interleaved sine-wave PCM.
  ///
  /// Both channels receive the same phase-aligned signal. Caller owns [pcm]
  /// and must allocate at least frames multiplied by channels floats.
  static void generateSine(
    Pointer<Float> pcm, {
    required int frames,
    required int channels,
    required double sampleRateHz,
    required double frequencyHz,
    required double amplitude,
  }) {
    if (pcm == nullptr ||
        frames <= 0 ||
        (channels != 1 && channels != 2) ||
        !sampleRateHz.isFinite ||
        !frequencyHz.isFinite ||
        !amplitude.isFinite ||
        sampleRateHz <= 0 ||
        frequencyHz <= 0 ||
        frequencyHz >= sampleRateHz / 2 ||
        amplitude <= 0 ||
        amplitude > 1) {
      throw ArgumentError('Invalid PCM buffer or sine-wave parameters.');
    }
    final angularStep = 2 * math.pi * frequencyHz / sampleRateHz;
    for (var frame = 0; frame < frames; frame++) {
      final sample = amplitude * math.sin(angularStep * frame);
      for (var channel = 0; channel < channels; channel++) {
        pcm[frame * channels + channel] = sample;
      }
    }
  }
}
