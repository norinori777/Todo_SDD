import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/review_probe.dart';

void main() {
  test('zero is not positive', () {
    expect(reviewProbeIsPositive(0), isFalse);
  });
}
