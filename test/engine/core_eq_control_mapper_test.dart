import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/engine/core_eq_control_mapper.dart';

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
      expect(
        CoreEqControlMapper.presetGainsDb['Flat'],
        everyElement(0),
      );
    });
  });
}
