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
    required this.peakLevel,
    this.error,
  });

  final bool running;
  final int sampleRateHz;
  final int channels;
  final String source;
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

  Future<CoreEqAndroidAudioStatus> startTestTone() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('startTestTone');
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
