import 'package:flutter_test/flutter_test.dart';
import 'package:core_eq/native/core_eq_native.dart';

void main() {
  group('CoreEqStatus.fromCode', () {
    test('maps all status codes defined by ABI version 1', () {
      expect(CoreEqStatus.fromCode(0), CoreEqStatus.ok);
      expect(CoreEqStatus.fromCode(1), CoreEqStatus.invalidArgument);
      expect(CoreEqStatus.fromCode(2), CoreEqStatus.queueFull);
    });

    test('does not misreport unknown native statuses as invalid arguments', () {
      expect(CoreEqStatus.fromCode(-1), CoreEqStatus.unknown);
      expect(CoreEqStatus.fromCode(3), CoreEqStatus.unknown);
      expect(CoreEqStatus.fromCode(99), CoreEqStatus.unknown);
    });
  });
}
