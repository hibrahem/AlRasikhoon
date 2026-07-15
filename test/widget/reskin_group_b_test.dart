import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/grade_display.dart';
import 'package:al_rasikhoon/shared/widgets/level_progression_widget.dart';
import '../support/theme_test_harness.dart';

void main() {
  testWidgets('GradeDisplay renders in both themes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    for (final b in Brightness.values) {
      await pumpInTheme(
        tester,
        brightness: b,
        child: const GradeDisplay(errorCount: 2),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('LevelProgressionWidget mastery ladder renders in both themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 300));
    for (final b in Brightness.values) {
      await pumpInTheme(
        tester,
        brightness: b,
        child: const LevelProgressionWidget(
          currentLevel: 4,
          unlockedLevels: [1, 2, 3, 4],
          completedLevels: [1, 2, 3],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('راسخ'), findsOneWidget);
      expect(find.text('محب'), findsOneWidget);
    }
  });
}
