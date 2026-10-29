import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Status reported by the Android generated-tone playback spike.
@immutable
final class CoreEqAndroidAudioStatus {
  const CoreEqAndroidAudioStatus({
    required this.running,
    required this.sampleRateHz,
    required this.channels,
    required this.source,
    this.frequencyHz = 440,
    this.amplitude = 0.06,
    required this.peakLevel,
    this.error,
  });

  final bool running;
  final int sampleRateHz;
  final int channels;
  final String source;
  final int frequencyHz;
  final double amplitude;
  /// Linear peak amplitude reported by native DSP, clamped to 0..1.
  final double peakLevel;
  final String? error;

  factory CoreEqAndroidAudioStatus.fromMap(Map<Object?, Object?> map) {
    final rawPeak = map['peakLevel'];
    final peak = rawPeak is num ? rawPeak.toDouble() : 0.0;
    return CoreEqAndroidAudioStatus(
      running: map['running'] == true,
      sampleRateHz: map['sampleRateHz'] is int ? map['sampleRateHz']! as int : 0,
      channels: map['channels'] is int ? map['channels']! as int : 0,
      source: map['source'] is String ? map['source']! as String : 'unknown',
      frequencyHz: map['frequencyHz'] is int ? map['frequencyHz']! as int : 440,
      amplitude: map['amplitude'] is num ? (map['amplitude']! as num).toDouble() : 0.06,
      peakLevel: peak.isFinite ? peak.clamp(0.0, 1.0).toDouble() : 0.0,
      error: map['error'] is String ? map['error']! as String : null,
    );
  }
}

/// Controls only the Android generated test tone processed by native CORE-EQ.
///
/// This is deliberately not microphone capture or system-wide audio routing.
/// PCM stays in a direct native buffer and never crosses the method channel.
final class CoreEqAndroidAudio {
  CoreEqAndroidAudio({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('core_eq_audio');

  final MethodChannel _channel;

  Future<CoreEqAndroidAudioStatus> startTestTone({
    int frequencyHz = 440,
    double amplitude = 0.06,
  }) async {
    const allowed = <int>{32, 64, 125, 250, 440, 1000};
    if (!allowed.contains(frequencyHz)) {
      throw ArgumentError.value(frequencyHz, 'frequencyHz', 'Unsupported test tone frequency.');
    }
    if (!amplitude.isFinite || amplitude < 0.02 || amplitude > 0.12) {
      throw ArgumentError.value(amplitude, 'amplitude', 'Test tone level must be between 0.02 and 0.12.');
    }
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'startTestTone', {'frequencyHz': frequencyHz, 'amplitude': amplitude},
    );
    if (result == null) {
      throw PlatformException(
        code: 'EMPTY_AUDIO_STATUS',
        message: 'Android audio plugin returned no playback status.',
      );
    }
    return CoreEqAndroidAudioStatus.fromMap(result);
  }

  Future<CoreEqAndroidAudioStatus> stop() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('stop');
    if (result == null) {
      throw PlatformException(
        code: 'EMPTY_AUDIO_STATUS',
        message: 'Android audio plugin returned no playback status.',
      );
    }
    return CoreEqAndroidAudioStatus.fromMap(result);
  }

  Future<void> setBandGain(int band, double gainDb) async {
    await _channel.invokeMethod<void>('setBandGain', {
      'band': band,
      'gainDb': gainDb,
    });
  }

  Future<void> setOutputGain(double gainDb) async {
    await _channel.invokeMethod<void>('setOutputGain', {'gainDb': gainDb});
  }

  Future<void> setSpatialEnabled(bool enabled) async {
    await _channel.invokeMethod<void>('setSpatialEnabled', {'enabled': enabled});
  }

  Future<void> setLimiterEnabled(bool enabled) async {
    await _channel.invokeMethod<void>('setLimiterEnabled', {'enabled': enabled});
  }

  Future<void> setBypassed(bool bypassed) async {
    await _channel.invokeMethod<void>('setBypassed', {'bypassed': bypassed});
  }

  Future<CoreEqMediaStatus> playMedia(String uri) async {
    if (uri.trim().isEmpty) throw ArgumentError.value(uri, 'uri', 'Media URI cannot be empty.');
    final result = await _channel.invokeMapMethod<Object?, Object?>('playMedia', {'uri': uri});
    if (result == null) throw PlatformException(code: 'EMPTY_MEDIA_STATUS', message: 'Android returned no media status.');
    return CoreEqMediaStatus.fromMap(result);
  }

  Future<CoreEqMediaStatus> pauseMedia() => _mediaCommand('pauseMedia');
  Future<CoreEqMediaStatus> resumeMedia() => _mediaCommand('resumeMedia');
  Future<CoreEqMediaStatus> stopMedia() => _mediaCommand('stopMedia');
  Future<CoreEqMediaStatus> readMediaStatus() => _mediaCommand('mediaStatus');

  Future<CoreEqMediaStatus> seekMedia(Duration position) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'seekMedia', {'positionMs': position.inMilliseconds.clamp(0, 1 << 62)},
    );
    if (result == null) throw PlatformException(code: 'EMPTY_MEDIA_STATUS', message: 'Android returned no media status.');
    return CoreEqMediaStatus.fromMap(result);
  }

  Future<CoreEqMediaStatus> _mediaCommand(String method) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(method);
    if (result == null) throw PlatformException(code: 'EMPTY_MEDIA_STATUS', message: 'Android returned no media status.');
    return CoreEqMediaStatus.fromMap(result);
  }

  Future<CoreEqAndroidAudioStatus> readStatus() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('status');
    if (result == null) {
      throw PlatformException(
        code: 'EMPTY_AUDIO_STATUS',
        message: 'Android audio plugin returned no playback status.',
      );
    }
    return CoreEqAndroidAudioStatus.fromMap(result);
  }
}


@immutable
final class CoreEqMediaStatus {
  const CoreEqMediaStatus({
    required this.isPlaying,
    required this.playWhenReady,
    required this.state,
    required this.positionMs,
    required this.durationMs,
    required this.mediaUri,
    this.inputPeakLevel = 0.0,
    this.outputPeakLevel = 0.0,
    this.processedFrames = 0,
    this.sampleRateHz = 0,
    this.channels = 0,
  });

  final bool isPlaying;
  final bool playWhenReady;
  final String state;
  final int positionMs;
  final int? durationMs;
  final String? mediaUri;
  final double inputPeakLevel;
  final double outputPeakLevel;
  final int processedFrames;
  final int sampleRateHz;
  final int channels;

  factory CoreEqMediaStatus.fromMap(Map<Object?, Object?> map) => CoreEqMediaStatus(
    isPlaying: map['isPlaying'] == true,
    playWhenReady: map['playWhenReady'] == true,
    state: map['state'] is String ? map['state']! as String : 'idle',
    positionMs: map['positionMs'] is num ? (map['positionMs']! as num).toInt() : 0,
    durationMs: map['durationMs'] is num ? (map['durationMs']! as num).toInt() : null,
    mediaUri: map['mediaUri'] is String ? map['mediaUri']! as String : null,
    inputPeakLevel: _finiteLevel(map['inputPeakLevel']),
    outputPeakLevel: _finiteLevel(map['outputPeakLevel']),
    processedFrames: map['processedFrames'] is num ? (map['processedFrames']! as num).toInt().clamp(0, 1 << 62) : 0,
    sampleRateHz: map['sampleRateHz'] is num ? (map['sampleRateHz']! as num).toInt() : 0,
    channels: map['channels'] is num ? (map['channels']! as num).toInt() : 0,
  );

  static double _finiteLevel(Object? value) {
    final number = value is num ? value.toDouble() : 0.0;
    return number.isFinite && number >= 0 ? number : 0.0;
  }
}
