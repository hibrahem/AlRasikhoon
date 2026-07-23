import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/shared/widgets/text_scale_clamp.dart';

/// The app honors the device's font-size setting only up to a ceiling: beyond
/// it, dense Arabic screens (dialogs especially) degrade into mid-word line
/// breaks. Moderate accessibility scaling passes through untouched.
void main() {
  Future<double> effectiveScaleOf10(WidgetTester tester, double ambient) async {
    late double scaled;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(ambient)),
        child: TextScaleClamp(
          child: Builder(
            builder: (context) {
              scaled = MediaQuery.textScalerOf(context).scale(10);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return scaled;
  }

  testWidgets('an extreme device font size is clamped to the ceiling', (
    tester,
  ) async {
    final scaled = await effectiveScaleOf10(tester, 2.0);
    expect(scaled, 10 * TextScaleClamp.maxScaleFactor);
  });

  testWidgets('moderate accessibility scaling passes through untouched', (
    tester,
  ) async {
    final scaled = await effectiveScaleOf10(tester, 1.1);
    expect(scaled, closeTo(11, 0.01));
  });
}
