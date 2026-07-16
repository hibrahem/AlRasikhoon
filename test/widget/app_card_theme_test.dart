import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_tokens.dart';
import 'package:al_rasikhoon/shared/widgets/app_card.dart';
import '../support/theme_test_harness.dart';

void main() {
  testWidgets('AppCard uses card token background in dark mode', (
    tester,
  ) async {
    await pumpInTheme(
      tester,
      brightness: Brightness.dark,
      child: const AppCard(child: Text('محتوى')),
    );
    // The card surface is painted by the decorated container (the Material
    // above it is transparent, existing only for ink effects).
    final container = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(AppCard),
            matching: find.byType(Container),
          ),
        )
        .firstWhere((c) => c.decoration is BoxDecoration);
    expect((container.decoration! as BoxDecoration).color, AppTokens.dark.card);
  });

  testWidgets('illuminated AppCard draws a gold border', (tester) async {
    await pumpInTheme(
      tester,
      child: const AppCard(illuminated: true, child: Text('محتوى')),
    );
    final container = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).border != null,
        );
    final border = (container.decoration as BoxDecoration).border as Border;
    expect(border.top.color, AppTokens.light.gold);
  });
}
