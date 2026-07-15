// test/unit/shared/juz_ring_sweep_test.dart
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/juz_ring.dart';

void main() {
  test('sweep maps progress to radians and clamps', () {
    expect(juzRingSweep(0), 0);
    expect(juzRingSweep(1), closeTo(2 * math.pi, 1e-9));
    expect(juzRingSweep(0.5), closeTo(math.pi, 1e-9));
    expect(juzRingSweep(-0.2), 0);
    expect(juzRingSweep(1.5), closeTo(2 * math.pi, 1e-9));
  });
}
