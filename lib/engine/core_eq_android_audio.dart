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
    this.error,
  });

  final bool running;
  final int sampleRateHz;
  final int channels;
  final String source;
  final String? error;

  factory CoreEqAndroidAudioStatus.fromMap(Map<Object?, Object?> map) {
    return CoreEqAndroidAudioStatus(
      running: map['running'] == true,
      sampleRateHz: map['sampleRateHz'] is int ? map['sampleRateHz']! as int : 0,
      channels: map['channels'] is int ? map['channels']! as int : 0,
      source: map['source'] is String ? map['source']! as String : 'unknown',
      error: map['error'] as String?,
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
