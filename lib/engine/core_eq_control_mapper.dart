import '../native/core_eq_native.dart';

/// Ten-band consumer controls translated to the native parametric EQ API.
///
/// This adapter only submits parameters to an already-open native session. It
/// does not create an audio stream or claim to process device-wide audio.
final class CoreEqControlMapper {
  CoreEqControlMapper(this._engine);

  final CoreEqEngineSession _engine;

  static const frequenciesHz = <double>[
    32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];
  static const q = 1.0;
  static const sampleRateHz = 48000.0;

  /// Preset gain curves, ordered from 32 Hz through 16 kHz.
  static const presetGainsDb = <String, List<double>>{
    'Flat': <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Bass': <double>[5, 4, 3, 1, 0, 0, 0, 0, 0, 0],
    'Vocal': <double>[-2, -1, 0, 1, 2, 3, 3, 2, 1, 0],
    'Rock': <double>[4, 3, 1, -1, -1, 1, 3, 4, 4, 3],
    'Podcast': <double>[-4, -3, -1, 2, 3, 2, 1, 0, -1, -2],
  };

  /// Applies one named preset to all ten native filters.
  ///
  /// Returns false when any native call reports a non-OK status. Calls are
  /// submitted sequentially because the native parameter queue is SPSC.
  bool applyPreset(String name) {
    final gains = presetGainsDb[name];
    if (gains == null) {
      throw ArgumentError.value(name, 'name', 'Unknown CORE-EQ preset');
    }
    var success = true;
    for (var band = 0; band < frequenciesHz.length; band++) {
      final status = _engine.configureBand(
        band: band,
        frequencyHz: frequenciesHz[band],
        q: q,
        gainDb: gains[band],
        sampleRateHz: sampleRateHz,
      );
      if (status != CoreEqStatus.ok) success = false;
    }
    return success;
  }

  /// Applies the consumer output control in decibels.
  bool setOutputLevelDb(double db) =>
      _engine.setOutputGainDb(db) == CoreEqStatus.ok;

  /// Enables or disables native bypass.
  bool setBypassed(bool bypassed) =>
      _engine.setBypassed(bypassed) == CoreEqStatus.ok;

  /// Resets the native processing engine.
  bool reset() => _engine.reset() == CoreEqStatus.ok;
}
