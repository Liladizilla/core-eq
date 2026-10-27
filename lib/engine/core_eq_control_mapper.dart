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

  /// Submits one band update to the native engine.
  ///
  /// Invalid band indices are rejected before crossing the FFI boundary.
  /// A false result means the native engine rejected the update, including
  /// when its bounded parameter queue is full.
  bool applyBand(int band, double gainDb) {
    if (band < 0 || band >= frequenciesHz.length) {
      throw RangeError.range(band, 0, frequenciesHz.length - 1, 'band');
    }
    if (!gainDb.isFinite || gainDb < -12 || gainDb > 12) {
      throw ArgumentError.value(
        gainDb,
        'gainDb',
        'Expected a finite gain from -12 dB through +12 dB.',
      );
    }
    return _engine.configureBand(
          band: band,
          frequencyHz: frequenciesHz[band],
          q: q,
          gainDb: gainDb,
          sampleRateHz: sampleRateHz,
        ) ==
        CoreEqStatus.ok;
  }

  /// Applies one named preset to all ten native filters.
  ///
  /// Stops at the first rejected event instead of flooding an already-full
  /// native queue with the remaining preset updates. Updates already accepted
  /// by the native queue are not rolled back.
  bool applyPreset(String name) {
    final gains = presetGainsDb[name];
    if (gains == null) {
      throw ArgumentError.value(name, 'name', 'Unknown CORE-EQ preset');
    }
    for (var band = 0; band < frequenciesHz.length; band++) {
      if (!applyBand(band, gains[band])) return false;
    }
    return true;
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
