import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/engine/core_eq_control_mapper.dart';
import 'package:core_eq/native/core_eq_native.dart';

final class _FakeEngine implements CoreEqEngineControls {
  final bands = <({int band, double frequencyHz, double q, double gainDb, double sampleRateHz})>[];
  CoreEqStatus nextBandStatus = CoreEqStatus.ok;
  CoreEqStatus outputStatus = CoreEqStatus.ok;
  CoreEqStatus bypassStatus = CoreEqStatus.ok;
  CoreEqStatus resetStatus = CoreEqStatus.ok;

  @override
  CoreEqStatus configureBand({
    required int band,
    required double frequencyHz,
    required double q,
    required double gainDb,
    required double sampleRateHz,
  }) {
    bands.add((band: band, frequencyHz: frequencyHz, q: q, gainDb: gainDb, sampleRateHz: sampleRateHz));
    return nextBandStatus;
  }

  @override
  CoreEqStatus setOutputGainDb(double db) => outputStatus;

  @override
  CoreEqStatus setBypassed(bool bypassed) => bypassStatus;

  @override
  CoreEqStatus reset() => resetStatus;
}

void main() {
  group('CoreEqControlMapper configuration', () {
    test('defines ten ordered graphic EQ bands', () {
      expect(CoreEqControlMapper.frequenciesHz, <double>[
        32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
      ]);
      expect(CoreEqControlMapper.frequenciesHz, hasLength(10));
    });

    test('all consumer presets provide ten finite gains within safe UI range', () {
      expect(CoreEqControlMapper.presetGainsDb.keys,
          containsAll(<String>['Flat', 'Bass', 'Vocal', 'Rock', 'Podcast']));
      for (final gains in CoreEqControlMapper.presetGainsDb.values) {
        expect(gains, hasLength(10));
        for (final gain in gains) {
          expect(gain.isFinite, isTrue);
          expect(gain, inInclusiveRange(-12, 12));
        }
      }
    });

    test('Flat preset does not alter any band gain', () {
      expect(CoreEqControlMapper.presetGainsDb['Flat'], everyElement(0));
    });
  });

  group('CoreEqControlMapper behavior', () {
    test('maps a band to the expected frequency and fixed processing settings', () {
      final engine = _FakeEngine();
      final mapper = CoreEqControlMapper(engine);

      expect(mapper.applyBand(5, 3.5), isTrue);
      expect(engine.bands, hasLength(1));
      expect(engine.bands.single.band, 5);
      expect(engine.bands.single.frequencyHz, 1000);
      expect(engine.bands.single.q, CoreEqControlMapper.q);
      expect(engine.bands.single.gainDb, 3.5);
      expect(engine.bands.single.sampleRateHz, CoreEqControlMapper.sampleRateHz);
    });

    test('rejects invalid band and gain before calling native controls', () {
      final engine = _FakeEngine();
      final mapper = CoreEqControlMapper(engine);

      expect(() => mapper.applyBand(-1, 0), throwsRangeError);
      expect(() => mapper.applyBand(10, 0), throwsRangeError);
      expect(() => mapper.applyBand(0, double.nan), throwsArgumentError);
      expect(() => mapper.applyBand(0, 12.1), throwsArgumentError);
      expect(engine.bands, isEmpty);
    });

    test('stops a preset immediately when native queue rejects a band', () {
      final engine = _FakeEngine()..nextBandStatus = CoreEqStatus.queueFull;
      final mapper = CoreEqControlMapper(engine);

      expect(mapper.applyPreset('Bass'), isFalse);
      expect(engine.bands, hasLength(1));
    });

    test('returns native failures for output, bypass, and reset', () {
      final engine = _FakeEngine()
        ..outputStatus = CoreEqStatus.queueFull
        ..bypassStatus = CoreEqStatus.invalidArgument
        ..resetStatus = CoreEqStatus.unknown;
      final mapper = CoreEqControlMapper(engine);

      expect(mapper.setOutputLevelDb(2), isFalse);
      expect(mapper.setBypassed(true), isFalse);
      expect(mapper.reset(), isFalse);
    });

    test('rejects unknown preset names', () {
      expect(() => CoreEqControlMapper(_FakeEngine()).applyPreset('Nightcore'),
          throwsArgumentError);
    });
  });
}
