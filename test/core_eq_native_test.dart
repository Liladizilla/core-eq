import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/native/core_eq_native.dart';

void main() {
  group('CORE-EQ native library packaging', () {
    test('uses Android/Linux shared object name', () {
      expect(
        CoreEqNative.libraryNameForPlatform(TargetPlatform.android),
        'libcore_eq.so',
      );
      expect(
        CoreEqNative.libraryNameForPlatform(TargetPlatform.linux),
        'libcore_eq.so',
      );
    });

    test('resolves desktop library names', () {
      expect(
        CoreEqNative.libraryNameForPlatform(TargetPlatform.windows),
        'core_eq.dll',
      );
      expect(
        CoreEqNative.libraryNameForPlatform(TargetPlatform.macOS),
        'libcore_eq.dylib',
      );
    });

    test('does not pretend iOS uses a regular dynamic library', () {
      expect(
        () => CoreEqNative.libraryNameForPlatform(TargetPlatform.iOS),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('unknown native status codes remain explicitly unknown', () {
      expect(CoreEqStatus.fromCode(999), CoreEqStatus.unknown);
    });
  });
}
