// test/widget/juz_ring_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/juz_ring.dart';
import '../support/theme_test_harness.dart';

void main() {
  testWidgets('JuzRing shows juz and percent, no overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    await pumpInTheme(
      tester,
      child: const Center(child: JuzRing(juz: 18, progress: 0.6)),
    );
    expect(find.text('الجزء 18'), findsOneWidget);
    expect(find.text('60٪'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
